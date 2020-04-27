CREATE OR REPLACE FUNCTION make_trajectory(accum geometry, point geometry)
    RETURNS geometry AS
$BODY$ DECLARE
    result PUBLIC.GEOMETRY;
BEGIN
    SET search_path = 'public';
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