sql_library
===========

Sql scripts and unit tests

Test Scripts
------------

Unit testing scripts can be found in the test directory.  

Unit testing is performed with pgTap

Install pgTap on the postgres server where testing is to be performed. For Debian systems:

> sudo apt-get install pgtap

and then in the database where you would like to run your test scripts, run the postgres command:

> create extension pgtap;

You can then run the test scripts from the command line using

> pg_prove -d <database_name> test/extension/imos/*

as the postgres user for example.

