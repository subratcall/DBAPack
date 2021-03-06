COL MEGAS FORMAT 9G999G999G999
COL EXTENTS FORMAT 999G999
COL TEMPFILE FORMAT A50
COL USERNAME FORMAT A30
BREAK ON TEMPFILE SKIP 1

SET FEED OFF  VERIFY OFF

COL "Tablespace"        FORMAT A10
COL "ExtentsCnt"        FORMAT A10
COL "CurrSizeMb"        FORMAT A10
COL "CurrFreeMb"        FORMAT A10
COL "TbsMaxSizeMb"      FORMAT A12
COL "MaxUsedMb"         FORMAT A9
COL "MaxSortMb"         FORMAT A9
COL "Extent/Segment Management" FORMAT A30

SELECT 
   T.TABLESPACE_NAME "Tablespace"
  ,LPAD( TO_CHAR( F.BLOCKS * T.BLOCK_SIZE/1048576, 'fm999g999' ), 12, ' ' ) "TbsMaxSizeMb"
  ,LPAD( TO_CHAR( S.TOTAL_BLOCKS * T.BLOCK_SIZE / 1048576, 'fm999g999' ), 10, ' ' ) "CurrSizeMb"
  ,LPAD( TO_CHAR( S.FREE_BLOCKS * T.BLOCK_SIZE / 1048576, 'fm999g999' ), 10, ' ' ) "CurrFreeMb"
  ,T.EXTENT_MANAGEMENT || ' ' || T.ALLOCATION_TYPE || ' ' ||
   TO_CHAR( S.EXTENT_SIZE * T.BLOCK_SIZE / 1048576, 'fm9g999' ) || 'Mb, '  ||
   T.SEGMENT_SPACE_MANAGEMENT "Extent/Segment Management"
FROM DBA_TABLESPACES T
JOIN ( SELECT TABLESPACE_NAME, SUM(GREATEST(MAXBLOCKS, BLOCKS)) BLOCKS FROM DBA_TEMP_FILES GROUP BY TABLESPACE_NAME ) F ON ( F.TABLESPACE_NAME = T.TABLESPACE_NAME )
JOIN (
  SELECT TABLESPACE_NAME, SUM(TOTAL_BLOCKS) TOTAL_BLOCKS, SUM(FREE_BLOCKS) FREE_BLOCKS,  MAX(EXTENT_SIZE) EXTENT_SIZE 
  FROM GV$SORT_SEGMENT GROUP BY TABLESPACE_NAME ) S ON ( S.TABLESPACE_NAME = F.TABLESPACE_NAME  )
/

SELECT S.INST_ID,
  S.TABLESPACE_NAME "Tablespace"
 ,LPAD( TO_CHAR( S.TOTAL_BLOCKS * T.BLOCK_SIZE / 1048576, 'fm999g999' ), 10, ' ' ) "CurrSizeMb"
 ,LPAD( TO_CHAR( S.FREE_BLOCKS * T.BLOCK_SIZE / 1048576, 'fm999g999' ), 10, ' ' ) "CurrFreeMb"
 ,LPAD( TO_CHAR( (S.TOTAL_BLOCKS-S.FREE_BLOCKS) * T.BLOCK_SIZE / 1048576, 'fm999g999' ), 10, ' ' ) "CurrUsedMb"
FROM GV$SORT_SEGMENT S, DBA_TABLESPACES T
WHERE S.TABLESPACE_NAME = T.TABLESPACE_NAME
ORDER BY 4 DESC
/

PROMPT
PROMPT TOP 5 CONSUMERS

SELECT * FROM 
(
 SELECT V.INST_ID, S.SID, V.SESSION_NUM SERIAL#, V.USERNAME, SUM(V.BLOCKS) * 8 / 1024 megas
 FROM GV$SORT_USAGE V
 LEFT JOIN GV$SESSION S ON (V.SESSION_NUM = S.SERIAL#)
 group by V.INST_ID, S.SID, V.SESSION_NUM, V.USERNAME
 order by megas desc
)
WHERE ROWNUM < 6
/

PROMPT
PROMPT DETALHES POR TEMPFILE

SET PAGES 300
WITH SU AS
(
  SELECT
    USERNAME, SEGFILE#, SEGRFNO#, SESSION_ADDR, INST_ID,
    SUM(BLOCKS) BLOCKS, SUM(EXTENTS) EXTENTS
  FROM GV$SORT_USAGE GROUP BY USERNAME, SEGFILE#, SEGRFNO#, SESSION_ADDR, INST_ID
),
PARAMETRO AS
(
  SELECT TO_NUMBER(VALUE) BLOCKSIZE
  FROM V$PARAMETER WHERE NAME = 'db_block_size'
)
SELECT /*+ALL_ROWS*/
   T.NAME TEMPFILE 
  ,DECODE(GROUPING(T.NAME)+GROUPING(U.USERNAME),1,'TOTAL DO TEMPFILE', 2, 'TOTAL DO TABLESPACE',U.USERNAME) USERNAME
  ,SUM(S.BLOCKS*P.BLOCKSIZE)/1024/1024 MEGAS
  --,SUM(S.EXTENTS)EXTENTS
  --,DECODE(GROUPING(T.NAME)+GROUPING(U.USERNAME),1,'TOTAL DO TEMPFILE', 2, 'TOTAL DO TABLESPACE',U.USERNAME) USERNAME
  --,GROUPING(T.NAME), GROUPING(U.USERNAME)
FROM
  SU S,
  PARAMETRO P,
  GV$SESSION U,
  V$TEMPFILE T
WHERE (U.SADDR = S.SESSION_ADDR AND U.INST_ID = S.INST_ID)
AND   T.RFILE# = S.SEGRFNO#
GROUP BY ROLLUP(T.NAME,U.USERNAME)
/

COL MEGAS CLEAR
COL TABLESPACE CLEAR

SET PAGES 66
PROMPT
SET FEED 6 VERIFY ON

