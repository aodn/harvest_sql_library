-- Tests for add_id_to_polygons

BEGIN;

SELECT plan(1);

-- handles null polygon

SELECT is(
    add_id_to_polygons(null),
    null,
    'should return null if passed null'
);

-- Finish the tests and clean up.
SELECT * FROM finish();

ROLLBACK;

