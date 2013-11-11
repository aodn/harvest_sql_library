-- Tests for add_point_shortest

BEGIN;

SELECT plan(8);

-- Return null if point is null

SELECT is( 
    st_astext(
        add_point_shortest(
           st_geomfromtext('LINESTRING(128 -35, 132 -45)'),
           null
        )
    ),
    null,
    'Return null if point is null'
);

-- Return null if point is not a point

SELECT is( 
    st_astext(
        add_point_shortest(
           st_geomfromtext('LINESTRING(128 -35, 132 -45)'),
           st_geomfromtext('LINESTRING(28 -5, 12 -5)')
        )
    ),
    null,
    'Return null if point is a linestring'
);

-- Add point < 180 degrees from end point of linestring

SELECT is( 
    st_astext(
        add_point_shortest(
           st_geomfromtext('LINESTRING(128 -35, 132 -45)'),
           st_makepoint(178, -60)
        )
    ),
    'LINESTRING(128 -35,132 -45,178 -60)',
    'Should append a point < 180 degrees from the end point of a linestring to the linestring'
);

-- Add point > 180 degrees from the end of the linestring

SELECT is( 
    st_astext(
        add_point_shortest(
           st_geomfromtext('LINESTRING(128 -35, -30 -45)'),
           st_makepoint(178, -60)
        )
    ),
    'MULTILINESTRING((128 -35,-30 -45,-180 -59.8026315789474),(180 -59.8026315789474,178 -60))',
    'Should create a multilinestring crossing the anti-meridian when adding a point > 180 degrees from the end point of the linestring '
);

-- Add point on anti-meridian to linestring with endpoint on anti-meridian with longitude of opposite sign

SELECT is( 
    st_astext(
        add_point_shortest(
           st_geomfromtext('LINESTRING(-128 -35, -180 -45)'),
           st_makepoint(180, -60)
        )
    ),
    'LINESTRING(-128 -35,-180 -45,-180 -60)',
    'Should append a point of longitude 180 to the end of the linestring translating longitude to -180'
);

SELECT is( 
    st_astext(
        add_point_shortest(
           st_geomfromtext('LINESTRING(128 -35, 180 -45)'),
           st_makepoint(-180, -60)
        )
    ),
    'LINESTRING(128 -35,180 -45,180 -60)',
    'Should append a point of longitude -180 to end of the linestring translating longitude to 180'
);

-- Add point to linestring with endpoint on anti-meridian with longitude of opposite sign

SELECT is( 
    st_astext(
        add_point_shortest(
           st_geomfromtext('LINESTRING(-128 -35, -180 -45)'),
           st_makepoint(170, -60)
        )
    ),
    'MULTILINESTRING((-128 -35,-180 -45),(180 -45,170 -60))',
    'Should create a multilinestring splitting line to point at the anti-meridian'
);

-- Add point on anti-meridian with longitude of opposite sign to the endpoint of the linestring

SELECT is( 
    st_astext(
        add_point_shortest(
           st_geomfromtext('LINESTRING(-128 -35, -170 -45)'),
           st_makepoint(180, -60)
        )
    ),
    'LINESTRING(-128 -35,-170 -45,-180 -60)',
    'Should append point changing sign of anti-meridian longitude'
);

-- Finish the tests and clean up.
SELECT * FROM finish();

ROLLBACK;
