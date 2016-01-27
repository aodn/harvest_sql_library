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
);


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

-- Function to return a set of cells created by dividing a specified region into a a specified cell size 
-- Refer http://gis.stackexchange.com/questions/16374/how-to-create-a-regular-polygon-grid-in-postgis

CREATE FUNCTION st_createfishnet(p_nrow integer, p_ncol integer, p_xsize double precision, p_ysize double precision, p_x0 double precision DEFAULT 0, p_y0 double precision DEFAULT 0, p_srid integer DEFAULT 4326, OUT "row" integer, OUT col integer, OUT cell geometry)
  RETURNS SETOF record AS
$BODY$
BEGIN
    RETURN QUERY (
      SELECT i + 1 AS row, j + 1 AS col, ST_Translate(geom, j * p_xsize + p_x0, i * p_ysize + p_y0) AS cell
        FROM generate_series(0, p_nrow - 1) AS i,
             generate_series(0, p_ncol - 1) AS j,
             (
               SELECT st_setsrid(('POLYGON((0 0, 0 '||p_ysize||', '||p_xsize||' '||p_ysize||', '||p_xsize||' 0,0 0))')::geometry, p_srid) AS geom
             ) AS foo
    );
END
$BODY$
LANGUAGE plpgsql IMMUTABLE STRICT;

-- Function to return a set of cells for the world divided up into a grid of a requested resolution 

CREATE FUNCTION create_grid_cells(p_resolution double precision, OUT "row" integer, OUT col integer, OUT cell geometry)
  RETURNS SETOF record AS
$BODY$
BEGIN
    RETURN QUERY (
      SELECT fishnet."row", fishnet.col, fishnet.cell
        FROM st_createfishnet((180/p_resolution)::integer, (360/p_resolution)::integer, p_resolution, p_resolution, -180, -90) AS fishnet
    );
END
$BODY$
LANGUAGE plpgsql IMMUTABLE STRICT;

-- Function to return a bounding polygon of a column in a table to the specified spatial resolution
-- Formed by dividing the world up into the specified cell size, identifying cells containing data 
-- and creating an aggregated multi-polygon from these cells removing common boundaries.

CREATE FUNCTION BoundingPolygon(p_schema_name text, p_table_name text, p_column_name text, p_resolution double precision)
    RETURNS geometry AS
$BODY$
DECLARE
    result text;
BEGIN
    -- Create bounding polygon by finding grid cells that intersect at least one geometry in the 
    -- specified table, aggregating them into one multi-polygon, removing any common boundaries using st_union
    -- and then simplifying (joining line segments that can be joined without changing the shape of the polygon)

    EXECUTE 'SELECT st_simplify(st_union(cell), 0)
               FROM create_grid_cells('||p_resolution||') AS grid_cell
              WHERE exists (
                  SELECT true
                    FROM '||p_schema_name||'.'||p_table_name||'
                   WHERE '||p_column_name||' && grid_cell.cell
                     AND st_intersects('||p_column_name||', grid_cell.cell)
                   LIMIT 1
              )'
    INTO result;

    RETURN result;
END;
$BODY$
LANGUAGE plpgsql; 

-- Function to add ids to polygons in provided gml

CREATE FUNCTION add_id_to_polygons( p_gml text )
  RETURNS text AS
$BODY$
DECLARE
    parts text[];
    result text;
BEGIN
    result := '';
    parts := regexp_split_to_array(p_gml, '<gml:Polygon');

    FOR i IN 1..array_length(parts, 1)-1 LOOP
        result := result||parts[i]||'<gml:Polygon gml:id="polygon'||i||'"';
    END LOOP;

    result := result||parts[array_length(parts, 1)];
    RETURN result;
END;
$BODY$
  LANGUAGE plpgsql;

-- Function to return a bounding polygon as gml 3
-- Use CRS:84 with lon/lat ordering rather than default EPSG:4326 with incorrect lon/lat ordering

CREATE FUNCTION BoundingPolygonAsGml3(p_schema_name text, p_table_name text, p_column_name text, p_resolution double precision)
    RETURNS text AS
$BODY$
DECLARE
    GML_3_1_1 CONSTANT integer := 3; -- GML version
    boundingPolygonAsGml text;
BEGIN
    boundingPolygonAsGml := ST_AsGml(GML_3_1_1, BoundingPolygon(p_schema_name, p_table_name, p_column_name, p_resolution));
    boundingPolygonAsGml := add_id_to_polygons(boundingPolygonAsGml);
    RETURN replace(boundingPolygonAsGml, 'EPSG:4326', 'CRS:84');
END;
$BODY$
LANGUAGE plpgsql; 

-- Legacy from postgis-2.0/legacy.sql

-- Deprecation in 1.2.3
CREATE FUNCTION MakePoint(float8, float8)
    RETURNS geometry AS 'SELECT ST_MakePoint($1, $2)'
    LANGUAGE 'sql' IMMUTABLE STRICT;


-- Deprecation in 1.2.3
CREATE FUNCTION MakePoint(float8, float8, float8)
    RETURNS geometry AS 'SELECT ST_MakePoint($1, $2, $3)'
    LANGUAGE 'sql' IMMUTABLE STRICT;


-- Deprecation in 1.2.3
CREATE FUNCTION MakePoint(float8, float8, float8, float8)
    RETURNS geometry AS 'SELECT ST_MakePoint($1, $2, $3, $4)'
    LANGUAGE 'sql' IMMUTABLE STRICT;


-- Deprecation in 1.2.3
CREATE FUNCTION GeomFromText(text, int4)
    RETURNS geometry AS 'SELECT ST_GeomFromText($1, $2)'
    LANGUAGE 'sql' IMMUTABLE STRICT;


-- Deprecation in 1.2.3
CREATE FUNCTION GeomFromText(text)
    RETURNS geometry AS 'SELECT ST_GeomFromText($1)'
    LANGUAGE 'sql' IMMUTABLE STRICT;


-- Schema management
CREATE FUNCTION exec(text) returns text
language plpgsql volatile
AS $f$
    BEGIN
    EXECUTE $1;
    RETURN $1;
    END;
$f$;
grant all on function exec(text) to public;


create function drop_objects_in_schema( schema text ) returns void
language plpgsql volatile
as $$
    begin
    perform exec( 'drop view if exists '||n.nspname||'.'||o.relname||' cascade' )
    from pg_class o
    left join pg_namespace n on n.oid=o.relnamespace
    where o.relkind = 'v'
    and n.nspname = $1;

    perform exec( 'alter table '||n.nspname||'.'||r.relname||' drop constraint if exists '||c.conname||' cascade' )
    from pg_constraint c
    left join pg_namespace n on n.oid = c.connamespace
    left join pg_class r ON r.oid = c.conrelid
    where n.nspname = $1;

    perform exec( 'drop index if exists '||n.nspname||'.'||o.relname||' cascade' )
    from pg_class o
    left join pg_namespace n on n.oid = o.relnamespace
    where o.relkind = 'i'
    and n.nspname = $1;

    perform exec( 'drop table if exists '||n.nspname||'.'||o.relname||' cascade' )
    from pg_class o
    left join pg_namespace n on n.oid = o.relnamespace
    where o.relkind = 'r'
    and n.nspname = $1;

    perform exec( 'drop sequence if exists '||n.nspname||'.'||o.relname|| ' cascade' )
    from pg_class o
    left join pg_namespace n on n.oid = o.relnamespace
    where o.relkind = 'S'
    and n.nspname = $1;

    perform exec( 'drop function if exists '||p.oid::regproc||'('||pg_get_function_identity_arguments( p.oid)||')'||' cascade' )
    FROM pg_proc p
    left join pg_namespace n ON n.oid = p.pronamespace
    where n.nspname = $1;
    end;
$$;

