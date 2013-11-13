/* contrib/imos/imos--1.0.sql */

-- complain if script is sourced in psql, rather than via CREATE EXTENSION
\echo Use "CREATE EXTENSION imos" to load this file. \quit

-- Harvester support

CREATE FUNCTION getendtoken(p_string character, p_regexp character, p_n integer)
RETURNS character AS
$$ DECLARE
	tokens text[];
BEGIN
    select into tokens regexp_split_to_array(p_string, p_regexp);
    return (select tokens[array_length(tokens,1)- p_n  + 1]);
END; $$
LANGUAGE plpgsql VOLATILE
COST 100;


CREATE FUNCTION format_name(p_name character)
RETURNS character AS
$$ DECLARE
    parts text[];
BEGIN
    select into parts (regexp_matches(initcap(p_name), '(.*)[ ,.]([a-zA-Z-]+)'));
    return (select parts[2]||', '||parts[1]);
END; $$
LANGUAGE plpgsql VOLATILE
COST 100;

-- Function to add a point to a linestring splitting the resulting line
-- at the anti-meridian if that is the shortest path from the endpoint of the
-- linestring to the point
-- NOTE: assumes points should never be more than 180 degrees longitude apart

CREATE FUNCTION add_point_shortest(linestring geometry, point geometry)
RETURNS geometry AS
$BODY$ DECLARE
    next_segment GEOMETRY;
BEGIN
    IF ((linestring is null) or (st_geometrytype(linestring)<>'ST_LineString') or (NOT is_valid_point(point))) THEN
        RETURN null;
    END IF;

    /* use make_shortest_line to work out the shortest line between the endpoint and the point */
    SELECT INTO next_segment make_shortest_line(st_endpoint(linestring), point);

    IF (st_geometrytype(next_segment) = 'ST_MultiLineString') THEN
        RETURN st_collect(st_addpoint(linestring, st_endpoint(st_geometryn(next_segment, 1))), st_geometryn(next_segment, 2));
    ELSIF (not st_equals(st_endpoint(linestring), st_startpoint(next_segment))) THEN
        /* endpoint was moved to anti-meridian of opposite sign to create the shortest line - create a multilinestring */
        RETURN st_collect(linestring, next_segment);
    ELSE
        RETURN st_addpoint(linestring, st_endpoint(next_segment));
    END IF;
END;
$BODY$
LANGUAGE plpgsql VOLATILE
COST 100;


CREATE FUNCTION make_trajectory(accum geometry, point geometry)
RETURNS geometry AS
$BODY$ DECLARE
    result GEOMETRY;
BEGIN
    IF (accum is null) THEN
        RETURN point;
    ELSIF (point is null) THEN
        RETURN accum;
    ELSIF (st_geometrytype(accum) = 'ST_Point') THEN
        RETURN make_shortest_line(accum, point);
    ELSIF (st_geometrytype(accum) = 'ST_LineString') THEN
        RETURN add_point_shortest(accum, point);
    ELSIF (st_geometrytype(accum) = 'ST_MultiLineString') THEN
        SELECT INTO result st_geometryn(accum, 1);

        FOR idx in 2 .. st_numgeometries(accum) - 1 LOOP
            SELECT INTO result st_collect(result, st_geometryn(accum, idx));
        END LOOP;

        RETURN st_collectionextract(st_collect(result, add_point_shortest(st_geometryn(accum, st_numgeometries(accum)), point)),2);
    ELSE
        RETURN null;
    END IF;
END;
$BODY$
LANGUAGE plpgsql VOLATILE
COST 100;


CREATE AGGREGATE make_trajectory(Geometry) (
    SFUNC = make_trajectory,
    STYPE = Geometry
)


CREATE FUNCTION is_valid_point(point geometry)
RETURNS boolean AS
$$
BEGIN
    IF ((point is null) or (st_geometrytype(point) <> 'ST_Point')) THEN
        RETURN false;
    END IF;

    RETURN true;
END;
$$
LANGUAGE plpgsql VOLATILE
COST 100;

CREATE FUNCTION make_point_or_shortest_line(pointa geometry, pointb geometry)
RETURNS geometry AS
$$
BEGIN

    IF (NOT (is_valid_point(pointa) AND is_valid_point(pointb))) THEN
        RETURN NULL;
    END IF;

    /*
     * Points are equal - return a point rather than a line string.
     * Ref: https://github.com/aodn/aodn-portal/issues/580
     */
    IF ((st_x(pointa) = st_x(pointb)) and (st_y(pointa) = st_y(pointb))) THEN
        RETURN pointa;
    END IF;

    RETURN make_shortest_line(pointa, pointb);
END;
$$
LANGUAGE plpgsql VOLATILE
COST 100;

-- Function to create a multilinestring representing the line joining two points
-- across the anti-meridian

CREATE FUNCTION make_line_crossing_antimeridian(pointa geometry, pointb geometry)
  RETURNS geometry AS
$BODY$
DECLARE
    pointashifted GEOMETRY;
    pointbshifted GEOMETRY;
    result GEOMETRY;
    shifted GEOMETRY;
    meridian_intersection GEOMETRY;
    meridian_intersection_unshifted GEOMETRY;
BEGIN
    SELECT INTO shifted st_shift_longitude(st_makeline(pointa, pointb));
    SELECT INTO pointashifted st_shift_longitude(pointa);
    SELECT INTO pointbshifted st_shift_longitude(pointb);
    SELECT INTO meridian_intersection st_line_interpolate_point(shifted, (180 - st_x(pointashifted)) / (st_x(pointbshifted) - st_x(pointashifted)));
    SELECT INTO meridian_intersection_unshifted st_translate(meridian_intersection, -360, 0);

    IF (st_x(pointa) < 0) THEN
        SELECT INTO result st_collect(st_makeline(pointa, meridian_intersection_unshifted), st_makeline(meridian_intersection, pointb));
    ELSE
        SELECT INTO result st_collect(st_makeline(pointa, meridian_intersection), st_makeline(meridian_intersection_unshifted, pointb));
    END IF;

    RETURN result;
END;
$BODY$
LANGUAGE plpgsql VOLATILE
COST 100;

-- Function to make the shortest line between two points splitting the line
-- at the anti-meridian if that is the shortest path
-- NOTE: assumes points should never be more than 180 degrees longitude apart

CREATE FUNCTION make_shortest_line(pointa geometry, pointb geometry)
RETURNS geometry AS
$BODY$
DECLARE
    result GEOMETRY;
BEGIN

    IF (NOT (is_valid_point(pointa) AND is_valid_point(pointb))) THEN
        RETURN NULL;
    END IF;

    IF ((st_x(pointa) not between -180 and 180) or (st_y(pointa) not between -90 and 90) or (st_x(pointb) not between -180 and 180) or (st_y(pointb) not between -90 and 90)) THEN
        RETURN null;
    END IF;

    IF (abs(st_x(pointb) - st_x(pointa))) <= 180 THEN
        /* point a and point b are less than 180 degrees longitude apart */
        /* shortest line is the line connecting the two points */
        SELECT INTO result st_makeline(pointa, pointb);
    ELSIF (abs(st_x(pointb)) = 180) THEN
        /* second point is on the anti-meridian of opposite sign to the first point */
        /* shortest line is the line from the first point to the second point moved */
        /* to the anti-meridian of the same sign */
        SELECT INTO result st_makeline(pointa, st_translate(pointb, - st_x(pointb) * 2, 0));
    ELSIF (abs(st_x(pointa)) = 180) THEN
        /* first point is on the anti-meridian of opposite longitude to the second point */
        /* shortest line is the line from the first point moved to the anti-meridian of the */
        /* same sign to the second point */
        SELECT INTO result st_makeline(st_translate(pointa, - st_x(pointa) * 2, 0), pointb);
    ELSE
        /* shortest line is a line crossing the anti-meridian split at the anti-meridian */
        SELECT INTO result make_line_crossing_antimeridian(pointa, pointb);
    END IF;
    
    RETURN result;
END;
$BODY$
LANGUAGE plpgsql VOLATILE
COST 100;


-- Legacy from postgis-2.0/legacy.sql

-- Deprecation in 1.2.3
CREATE FUNCTION MakePoint(float8, float8)
    RETURNS geometry
    AS '$libdir/postgis-2.0', 'LWGEOM_makepoint'
    LANGUAGE 'c' IMMUTABLE STRICT;


-- Deprecation in 1.2.3
CREATE FUNCTION MakePoint(float8, float8, float8)
    RETURNS geometry
    AS '$libdir/postgis-2.0', 'LWGEOM_makepoint'
    LANGUAGE 'c' IMMUTABLE STRICT;


-- Deprecation in 1.2.3
CREATE FUNCTION MakePoint(float8, float8, float8, float8)
    RETURNS geometry
    AS '$libdir/postgis-2.0', 'LWGEOM_makepoint'
    LANGUAGE 'c' IMMUTABLE STRICT;


-- Deprecation in 1.2.3
CREATE FUNCTION GeomFromText(text, int4)
    RETURNS geometry AS 'SELECT ST_GeomFromText($1, $2)'
    LANGUAGE 'sql' IMMUTABLE STRICT;


-- Deprecation in 1.2.3
CREATE FUNCTION GeomFromText(text)
    RETURNS geometry AS 'SELECT ST_GeomFromText($1)'
    LANGUAGE 'sql' IMMUTABLE STRICT;
