/* contrib/imos/imos--unpackaged--1.1.sql */

-- complain if script is sourced in psql, rather than via CREATE EXTENSION
\echo Use "CREATE EXTENSION imos" to load this file. \quit

-- Harvester
ALTER EXTENSION "imos" ADD function public.getendtoken();
ALTER EXTENSION "imos" ADD function public.format_name();
ALTER EXTENSION "imos" ADD function public.add_point_shortest();
ALTER EXTENSION "imos" ADD function public.make_trajectory();
ALTER EXTENSION "imos" ADD function public.make_shortest_line();

-- Legacy
ALTER EXTENSION "imos" ADD function public.MakePoint(float8, float8);
ALTER EXTENSION "imos" ADD function public.MakePoint(float8, float8, float8);
ALTER EXTENSION "imos" ADD function public.MakePoint(float8, float8, float8, float8);

ALTER EXTENSION "imos" ADD function public.GeomFromText(text, int4);
ALTER EXTENSION "imos" ADD function public.GeomFromText(text);

-- Schema management
ALTER EXTENSION "imos" ADD function public.exec(schema text);
ALTER EXTENSION "imos" ADD function public.drop_objects_in_schema(schema text);

-- Utility
ALTER EXTENSION "imos" ADD function public.database_activity();

