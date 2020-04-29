/* contrib/imos/imos--1.0--1.1.sql

   ## To manually update from 1.0 to 1.1
   ALTER EXTENSION imos UPDATE to '1.1'

   ## Fresh installation installs the version in imos.control

*/

-- complain if script is sourced in psql, rather than via CREATE EXTENSION
\echo Use "ALTER EXTENSION imos UPDATE to 1.1 to load this file if on version 1.0." \quit


ALTER FUNCTION getendtoken(character,  character,  integer)  SET search_path = public;
ALTER FUNCTION format_name(character)  SET search_path = public;
ALTER FUNCTION add_point_shortest(geometry,geometry)  SET search_path = public;
ALTER FUNCTION make_trajectory(geometry,geometry)  SET search_path = public;
ALTER FUNCTION is_valid_point(geometry)  SET search_path = public;
ALTER FUNCTION make_point_or_shortest_line(geometry,geometry)  SET search_path = public;
ALTER FUNCTION make_line_crossing_antimeridian(geometry,geometry)  SET search_path = public;
ALTER FUNCTION make_shortest_line(geometry,geometry)  SET search_path = public;
ALTER FUNCTION st_createfishnet(integer, integer, double precision, double precision, double precision, double precision, integer) SET search_path = public;
ALTER FUNCTION create_grid_cells(double precision)  SET search_path = public;
ALTER FUNCTION BoundingPolygon(text,text,text,double precision)  SET search_path = public;
ALTER FUNCTION add_id_to_polygons(text )  SET search_path = public;
ALTER FUNCTION BoundingPolygonAsGml3(text,text,text,double precision)  SET search_path = public;
ALTER FUNCTION MakePoint(float8, float8)  SET search_path = public;
ALTER FUNCTION MakePoint(float8, float8, float8)  SET search_path = public;
ALTER FUNCTION MakePoint(float8, float8, float8, float8)  SET search_path = public;
ALTER FUNCTION GeomFromText(text, int4)  SET search_path = public;
ALTER FUNCTION GeomFromText(text)  SET search_path = public;
ALTER FUNCTION exec(text)  SET search_path = public;
ALTER FUNCTION drop_objects_in_schema(schema text)  SET search_path = public;
ALTER FUNCTION database_activity()  SET search_path = public;



