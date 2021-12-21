/* contrib/imos/imos--1.1--1.2.sql

   ## To manually upgrade from 1.1 to 1.2
   ALTER EXTENSION imos UPDATE to '1.2'

   ## Fresh installation installs the version in imos.control

*/

-- complain if script is sourced in psql, rather than via CREATE EXTENSION
\echo Use "ALTER EXTENSION imos UPDATE to 1.2 to load this file if on version 1.1." \quit


ALTER FUNCTION getendtoken(character,  character,  integer) RESET search_path;
ALTER FUNCTION format_name(character) RESET search_path;
ALTER FUNCTION add_point_shortest(geometry,geometry) RESET search_path;
ALTER FUNCTION make_trajectory(geometry,geometry) RESET search_path;
ALTER FUNCTION is_valid_point(geometry) RESET search_path;
ALTER FUNCTION make_point_or_shortest_line(geometry,geometry) RESET search_path;
ALTER FUNCTION make_line_crossing_antimeridian(geometry,geometry) RESET search_path;
ALTER FUNCTION make_shortest_line(geometry,geometry) RESET search_path;
ALTER FUNCTION st_createfishnet(integer, integer, double precision, double precision, double precision, double precision, integer) RESET search_path;
ALTER FUNCTION create_grid_cells(double precision) RESET search_path;
ALTER FUNCTION BoundingPolygon(text,text,text,double precision) RESET search_path;
ALTER FUNCTION add_id_to_polygons(text ) RESET search_path;
ALTER FUNCTION BoundingPolygonAsGml3(text,text,text,double precision) RESET search_path;
ALTER FUNCTION MakePoint(float8, float8) RESET search_path;
ALTER FUNCTION MakePoint(float8, float8, float8) RESET search_path;
ALTER FUNCTION MakePoint(float8, float8, float8, float8) RESET search_path;
ALTER FUNCTION GeomFromText(text, int4) RESET search_path;
ALTER FUNCTION GeomFromText(text) RESET search_path;
ALTER FUNCTION exec(text) RESET search_path;
ALTER FUNCTION drop_objects_in_schema(schema text) RESET search_path;
ALTER FUNCTION database_activity() RESET search_path;



