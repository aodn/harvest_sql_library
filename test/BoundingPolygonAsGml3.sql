-- Tests for BoundingPolygonAsGml3

BEGIN;

-- Create test data

CREATE TABLE test_data
(
  "position" geometry(Geometry,4326)
);

INSERT INTO test_data ("position") VALUES
  (st_geomfromtext('POINT(1.5 41.3)', 4326)),
  (st_geomfromtext('POINT(3.1 44.8)', 4326)),
  (st_geomfromtext('POINT(4.6 44.3)', 4326)),
  (st_geomfromtext('POINT(7.6 43.3)', 4326)),
  (st_geomfromtext('POINT(4.8 45.6)', 4326));

SELECT plan(2);

-- 1 degree resolution - 3 polygons

SELECT is( 
    BoundingPolygonAsGml3(current_schema, 'test_data', 'position', 1),
    '<gml:MultiSurface srsName="EPSG:4326"><gml:surfaceMember><gml:Polygon><gml:exterior><gml:LinearRing><gml:posList srsDimension="2">1 41 1 42 2 42 2 41 1 41</gml:posList></gml:LinearRing></gml:exterior></gml:Polygon></gml:surfaceMember><gml:surfaceMember><gml:Polygon><gml:exterior><gml:LinearRing><gml:posList srsDimension="2">7 43 7 44 8 44 8 43 7 43</gml:posList></gml:LinearRing></gml:exterior></gml:Polygon></gml:surfaceMember><gml:surfaceMember><gml:Polygon><gml:exterior><gml:LinearRing><gml:posList srsDimension="2">3 44 3 45 4 45 4 46 5 46 5 45 5 44 4 44 3 44</gml:posList></gml:LinearRing></gml:exterior></gml:Polygon></gml:surfaceMember></gml:MultiSurface>',
    'Should make 3 polygons at 1 degree resolution'
);

-- 10 degree resolution - 1 polygon

SELECT is( 
    BoundingPolygonAsGml3(current_schema, 'test_data', 'position', 10),
    '<gml:Polygon srsName="EPSG:4326"><gml:exterior><gml:LinearRing><gml:posList srsDimension="2">0 40 0 50 10 50 10 40 0 40</gml:posList></gml:LinearRing></gml:exterior></gml:Polygon>',
    'Should make 1 polygon at 10 degree resolution'
);

-- Finish the tests and clean up.
SELECT * FROM finish();

ROLLBACK;

