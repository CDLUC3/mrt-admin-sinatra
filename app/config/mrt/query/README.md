# Query File Structure

The admin tool loads all files matching `app/config/mrt/query/query.sql.*.yml`.

The files may contain the following keys
- columns: special mapping rules for specific column names
- fragments: re-usable SQL fragments that may be referenced using Mustache templating
- queries: named queries to be executed

## Column Definitions

```
# columns: key for defining column definitions
columns:
  # specfic column names to match
  names:
    # name of a specific column
    inv_object_id: 
      # id: indicates that a numeric id should be displayed as a string with no comma formatting
      id: true,

      # idlist: indicates that a list of ids should be displayed as strings with no comma formatting
      # idlist: true,

      # prefix: create an anchor tag for the id with the following string as an href prefix
      prefix: '/queries/repository/object?inv_object_id='

      # header: user friendly column header
      header: Obj ID

      # if filterable is set to true, a drop down widget will be created for the table column
      # filterable: true

      # cssclass: assigns a specific css class to the the table cells for the column
      #  when a column value is numeric, default numeric formatting will be applied
      # cssclass: float
  # special pattern matching to apply to column names
  patterns:
    # in the admin tool, several date specific column names should be formatted numeric values
    '^\d{4}-\d{2}-\d{2}$':
      cssclass: float
```

## Query Fragments 

```
# fragments: key for defining fragments
fragments:
  # fragment name, note that ": |" allows multiple lines of SQL to be embedded in yaml
  COLLQ: |
    select
      c.id inv_collection_id,
      mnemonic,
      ark collection_ark,
      ...
  # note that fragments can reference other fragments (up to a depth of 3) using Mustache templating
  COLLQ2: |
    select
      c.id inv_collection_id,
      mnemonic,
      ark collection_ark
    {{{WHERE}}}
```

## Query Definitions

```
# queries: key for defining a named query
queries:
  # where possible, the query should match the sinatra route for a specific request
  /queries/consistency/replication/objects-2:
    # update: true.  If true, this indicates that the query performs an update.
    # non_report: true.  If true, this indicates that this query is not displayed as a report.
    # test_skip: true.  If true, do not include query in the unit test run.
    # status: Optional. If provided, this sets a default status for the report. 
    status: PASS
    # description: Optional.  Markdown to display as a report description.
    #   Parameter values can be injected into the report using Mustache templating.
    #   When a report as PASS/FAIL criteria, it is a good practice to describe that in the report description.  
    description: |
      This report will query `inv_nodes_inv_objects` to count the number of objects having an irregular number of replicated copies. 
      The Merritt system typically has one primary copy of an object and 2 secondary copies.
    # template-params: Optional.  Name/value pairs to be edited into a query using Mustache templating
    # template-params
    #   COPIES: 2
    #   WHERE: foo = 'bar'
    # template-sql: run a query that is used as input into another query
    # template-sql:
    #   RANGE: |
    #     {{{CUMLYEARS}}}
    # status_check: Optional.  If true, it triggers the results to be saved as a consistency check.
    status_check: true
    # totals: Optional.  If true, numeric columns will be summed and displayed as a table footer.
    totals: true
    # sql: Required.  May contain inline SQL or fragment references.
    sql: |
      {{{OBJREPLPRE}}}
      {{{REPSQL}}}
    # parameters: Must match the number of prepared statement parameters in the query.  
    #   Named url parameters are converted to positional parameters using the array order listed below
    parameters:
    - name: days
      type: integer
```