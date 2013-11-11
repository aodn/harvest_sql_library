/* contrib/imos/imos--unpackaged--1.0.sql */

-- complain if script is sourced in psql, rather than via CREATE EXTENSION
\echo Use "CREATE EXTENSION imos" to load this file. \quit

-- Harvester
ALTER EXTENSION "imos" ADD function getendtoken();
ALTER EXTENSION "imos" ADD function format_name();
ALTER EXTENSION "imos" ADD function add_point_shortest();
ALTER EXTENSION "imos" ADD function make_trajectory();
ALTER EXTENSION "imos" ADD function make_shortest_line();

-- Legacy
ALTER EXTENSION "imos" ADD function MakePoint(float8, float8);
ALTER EXTENSION "imos" ADD function MakePoint(float8, float8, float8); 
ALTER EXTENSION "imos" ADD function MakePoint(float8, float8, float8, float8);

ALTER EXTENSION "imos" ADD function GeomFromText(text, int4); 
ALTER EXTENSION "imos" ADD function GeomFromText(text); 


