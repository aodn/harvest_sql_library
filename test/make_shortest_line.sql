-- Tests for make_shortest_line

BEGIN;

SELECT plan(5);

-- Two points < 180 degrees apart

SELECT is( 
    st_astext(
        make_shortest_line(
           st_makepoint(132, -45),
           st_makepoint(178, -60)
        )
    ),
    'LINESTRING(132 -45,178 -60)',
    'Should create a simple linestring joining two points < 180 degrees apart'
);

-- Two points > 180 degrees apart

SELECT is( 
    st_astext(
        make_shortest_line(
           st_makepoint(-30, -45),
           st_makepoint(178, -60)
        )
    ),
    'MULTILINESTRING((-30 -45,-180 -59.8026315789474),(180 -59.8026315789474,178 -60))',
    'Should create a multilinestring crossing the ant-meridian split at the anti-meridian when the two points are > 180 degrees apart '
);

-- Two points on the anti-meridian but on different sides

SELECT is( 
    st_astext(
        make_shortest_line(
           st_makepoint(-180, -45),
           st_makepoint(180, -60)
        )
    ),
    'LINESTRING(-180 -45,-180 -60)',
    'Should create a simple linestring joining the two points on the first points side of the anti-meridian'
);

-- First point on the anti-meridian the other on the opposite side

SELECT is( 
    st_astext(
        make_shortest_line(
           st_makepoint(-180, -45),
           st_makepoint(170, -60)
        )
    ),
    'LINESTRING(180 -45,170 -60)',
    'Should create a line to the point from the anti-meridian closest to the point'
);

-- Second point on the anti-meridian the first on the opposite side

SELECT is( 
    st_astext(
        make_shortest_line(
           st_makepoint(-170, -60),
           st_makepoint(180, -45)
        )
    ),
    'LINESTRING(-170 -60,-180 -45)',
    'Should create a line from the point to the anti-meridian closest to the point'
);


-- Finish the tests and clean up.
SELECT * FROM finish();

ROLLBACK;