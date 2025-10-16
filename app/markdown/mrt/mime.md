[Source Code](https://github.com/CDLUC3/merritt-docker/blob/main/mrt-services/mysql/init.sql) for the source for this mapping.

```
CASE
      WHEN mime_type = 'text/csv' THEN 'data'
      WHEN mime_type = 'plain/turtle' THEN 'data'
      WHEN mime_type REGEXP '^application/(json|atom\.xml|marc|mathematica|x-hdf|x-matlab-data|x-sas|x-sh$|x-sqlite|x-stata)' THEN 'data'
      WHEN mime_type REGEXP '^application/.*(zip|gzip|tar|compress|zlib)' THEN 'container'
      WHEN mime_type REGEXP '^application/(x-font|x-web)' THEN 'web'
      WHEN mime_type REGEXP '^application/(x-dbf|vnd\.google-earth)' THEN 'geo'
      WHEN mime_type REGEXP '^application/vnd\.(rn-real|chipnuts)' THEN 'audio'
      WHEN mime_type REGEXP '^application/mxf' THEN 'video'
      WHEN mime_type REGEXP '^(message|model)/' THEN 'text'
      WHEN mime_type REGEXP '^(multipart|text/x-|application/java|application/x-executable|application/x-shockwave-flash)' THEN 'software'
      WHEN mime_type REGEXP '^application/' THEN 'text'
      ELSE substring_index(mime_type, '/', 1)
    END as mime_group,
```