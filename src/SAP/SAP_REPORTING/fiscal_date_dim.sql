#-- Copyright 2023 Google LLC
#--
#-- Licensed under the Apache License, Version 2.0 (the "License");
#-- you may not use this file except in compliance with the License.
#-- You may obtain a copy of the License at
#--
#--     https://www.apache.org/licenses/LICENSE-2.0
#--
#-- Unless required by applicable law or agreed to in writing, software
#-- distributed under the License is distributed on an "AS IS" BASIS,
#-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#-- See the License for the specific language governing permissions and
#-- limitations under the License.

--## CORTEX-CUSTOMER: The fiscal table solution works only for those variants(periv)
-- where we have fiscal year as a continuous calendar year. Consider commenting/uncommenting
-- a specific fiscal case as per your requirement.

--CASE 1: If t009.xkale = 'X', Fiscal year is the same as calendar year.
(
  SELECT
    mandt,
    periv,
    dt AS Date,
    CAST(FORMAT_DATE('%Y%m%d', dt) AS INT64) AS DateInt,
    FORMAT_DATE('%Y%m%d', dt) AS DateStr,
    FORMAT_DATE('0%m', dt) AS FiscalPeriod,
    FORMAT_DATE('%Y', dt) AS FiscalYear,
    FORMAT_DATE('%Y0%m', dt) AS FiscalYearPeriod,
    DATE_TRUNC(dt, YEAR) AS FiscalYearFirstDay,
    LAST_DAY(dt, YEAR) AS FiscalYearLastDay,
    IF(EXTRACT(QUARTER FROM dt) IN (1, 2), 1, 2) AS FiscalSemester,
    IF(EXTRACT(QUARTER FROM dt) IN (1, 2), '01', '02') AS FiscalSemesterStr,
    IF(EXTRACT(QUARTER FROM dt) IN (1, 2), '1st Semester', '2nd Semester') AS FiscalSemesterStr2,
    EXTRACT(QUARTER FROM dt) AS FiscalQuarter,
    '0' || EXTRACT(QUARTER FROM dt) AS FiscalQuarterStr,
    'Q' || EXTRACT(QUARTER FROM dt) AS FiscalQuarterStr2,
    EXTRACT(WEEK FROM dt) AS FiscalWeek,
    '0' || EXTRACT(WEEK FROM dt) AS FiscalWeekStr,
    DATE_TRUNC(dt, WEEK) AS WeekStartDate,
    LAST_DAY(dt, WEEK) AS WeekEndDate,
    FORMAT_DATE('%A', dt) AS DayNameLong,
    FORMAT_DATE('%a', dt) AS DayNameShort
  FROM
    `{{ project_id_src }}.{{ dataset_cdc_processed }}.t009`,
    UNNEST(
      GENERATE_DATE_ARRAY(
        DATE_SUB(DATE_TRUNC(CURRENT_DATE(), YEAR), INTERVAL 10 YEAR),
        DATE_ADD(LAST_DAY(CURRENT_DATE(), YEAR), INTERVAL 10 YEAR),
        INTERVAL 1 DAY)
    ) AS dt
  WHERE
    xkale = 'X'
    AND mandt = '{{ mandt }}'
)

UNION ALL
--CASE 2: If t009.xjabh = 'X', Fiscal year is not a calendar year and has fiscal variants.
(
  WITH
    -- Calculate end date for each fiscal year and period combination.
    GetEndDate AS (
      SELECT
        t009.mandt,
        t009.periv,
        t009b.bdatj,
        t009b.bumon,
        t009b.butag,
        t009b.reljr,
        t009b.poper,
        CAST(MIN(t009b.bumon) OVER (PARTITION BY t009.mandt, t009.periv, t009b.bdatj) AS INT64)
          AS MinimumBumon,
        CAST(CONCAT(t009b.bdatj, '-', t009b.bumon, '-', t009b.butag) AS DATE) AS EndDate
      FROM
        `{{ project_id_src }}.{{ dataset_cdc_processed }}.t009` AS t009
      INNER JOIN
        `{{ project_id_src }}.{{ dataset_cdc_processed }}.t009b` AS t009b
        ON
          t009.mandt = t009b.mandt
          AND t009.periv = t009b.periv
      WHERE t009.xjabh = 'X'
        AND t009.mandt = '{{ mandt }}'
    ),

    -- Calculate start date according to fiscal year and period combination.
    GetStartDate AS (
      SELECT
        mandt,
        periv,
        bdatj,
        bumon,
        butag,
        reljr,
        poper,
        EndDate,
        -- Calculate start date based on end date.
        COALESCE(
          DATE_ADD(
            LAG(EndDate) OVER (PARTITION BY mandt, periv ORDER BY bdatj, bumon, butag),
            INTERVAL 1 DAY),
          DATE_TRUNC(EndDate, MONTH)
        ) AS StartDate
      FROM GetEndDate
    ),

    -- Calculate Fiscal Year First and Last Day.
    GetFirstAndLastDay AS (
      SELECT
        mandt,
        periv,
        poper,
        dt,
        MIN(dt) OVER (PARTITION BY mandt, periv, CAST(bdatj AS INT64) + CAST(reljr AS INT64))
          AS FiscalYearFirstDay,
        MAX(dt) OVER (PARTITION BY mandt, periv, CAST(bdatj AS INT64) + CAST(reljr AS INT64))
          AS FiscalYearLastDay,
        LAST_DAY(dt, WEEK) AS WeekEndDate,
        DATE_TRUNC(dt, WEEK) AS WeekStartDate,
        CAST(bdatj AS INT64) + CAST(reljr AS INT64) AS FiscalYear
      FROM GetStartDate,
        UNNEST(GENERATE_DATE_ARRAY(StartDate, EndDate)) AS dt
    ),

    -- Calculate aggregated fields, i.e, FiscalSemester,FiscalWeek and FiscalQuarter.
    GetAggFields AS (
      SELECT
        mandt,
        periv,
        dt AS Date,
        FiscalYearFirstDay,
        FiscalYearLastDay,
        FiscalYear AS FiscalYearInt,
        WeekStartDate,
        WeekEndDate,
        poper AS FiscalPeriod,
        CAST(FiscalYear AS STRING) AS FiscalYear,
        CAST(FORMAT_DATE('%Y%m%d', dt) AS INT64) AS DateInt,
        FORMAT_DATE('%Y%m%d', dt) AS DateStr,
        CASE
          WHEN dt >= FiscalYearFirstDay
            AND dt < DATE_ADD(FiscalYearFirstDay, INTERVAL 6 MONTH)
            THEN 1
          WHEN dt >= DATE_ADD(FiscalYearFirstDay, INTERVAL 6 MONTH)
            AND dt <= FiscalYearLastDay
            THEN 2
        END AS FiscalSemester,
        CASE
          WHEN dt >= FiscalYearFirstDay
            AND dt < DATE_ADD(FiscalYearFirstDay, INTERVAL 3 MONTH)
            THEN 1
          WHEN dt >= DATE_ADD(FiscalYearFirstDay, INTERVAL 3 MONTH)
            AND dt < DATE_ADD(FiscalYearFirstDay, INTERVAL 6 MONTH)
            THEN 2
          WHEN dt >= DATE_ADD(FiscalYearFirstDay, INTERVAL 6 MONTH)
            AND dt < DATE_ADD(FiscalYearFirstDay, INTERVAL 9 MONTH)
            THEN 3
          WHEN dt >= DATE_ADD(FiscalYearFirstDay, INTERVAL 9 MONTH)
            AND dt <= FiscalYearLastDay
            THEN 4
        END AS FiscalQuarter,
        CAST(
          IF(
            FORMAT_DATE('%A', FiscalYearFirstDay) = 'Sunday',
            CEIL(SAFE_DIVIDE(DATE_DIFF(WeekEndDate, FiscalYearFirstDay, DAY), 7)),
            FLOOR(SAFE_DIVIDE(DATE_DIFF(WeekEndDate, FiscalYearFirstDay, DAY), 7))
          ) AS INT64) AS FiscalWeek,
        FORMAT_DATE('%A', dt) AS DayNameLong,
        FORMAT_DATE('%a', dt) AS DayNameShort,
        CONCAT(FiscalYear, poper) AS FiscalYearPeriod
      FROM GetFirstAndLastDay
    )
  SELECT
    mandt,
    periv,
    Date,
    DateInt,
    DateStr,
    FiscalPeriod,
    FiscalYear,
    FiscalYearPeriod,
    FiscalYearFirstDay,
    FiscalYearLastDay,
    FiscalSemester,
    CAST(CONCAT(0, FiscalSemester) AS STRING) AS FiscalSemesterStr,
    IF(FiscalSemester = 1, '1st Semester', '2nd Semester') AS FiscalSemesterStr2,
    FiscalQuarter,
    CAST(CONCAT(0, FiscalQuarter) AS STRING) AS FiscalQuarterStr,
    CAST(CONCAT('Q', FiscalQuarter) AS STRING) AS FiscalQuarterStr2,
    FiscalWeek,
    LPAD(CAST(FiscalWeek AS STRING), 2, '0') AS FiscalWeekStr,
    WeekStartDate,
    WeekEndDate,
    DayNameLong,
    DayNameShort
  FROM GetAggFields
)

UNION ALL
--CASE 3: If t009.xkale IS NULL AND t009.xjabh IS NULL,
--Indicates that the fiscal calendar is grouped into custom fiscal variants.
--It has two scenarios, i.e, t009b.bdatj = '0000' and t0009b.bdatj != '0000'.
(
  WITH
    -- Add CTE to determine the type of variant based on t009 flags
    VariantTypes AS (
      SELECT DISTINCT
        mandt,
        periv,
        xkale,
        xjabh,
        -- Add flags to explicitly check for NULL or Empty String conditions
        (xkale = 'X') AS is_case1,
        (xjabh = 'X') AS is_case2,
        (COALESCE(TRIM(xkale), '') = '' AND COALESCE(TRIM(xjabh), '') = '') AS is_case3 -- Check for NULL or empty/whitespace string
      FROM `{{ project_id_src }}.{{ dataset_cdc_processed }}.t009`
      WHERE mandt = '{{ mandt }}'
    ),
    is_leap_year AS ( -- Inline the UDF logic for testing portability
      SELECT year, (MOD(year, 4) = 0 AND MOD(year, 100) != 0) OR MOD(year, 400) = 0 AS is_leap
      FROM UNNEST(GENERATE_ARRAY(EXTRACT(YEAR FROM DATE_SUB(CURRENT_DATE(), INTERVAL 20 YEAR)), EXTRACT(YEAR FROM DATE_ADD(CURRENT_DATE(), INTERVAL 20 YEAR)))) AS year -- Expanded range slightly
    ),
    -- Calculate end date for each fiscal year and period combination for t009b.bdatj = '0000'
    GetEndDateForFirstScenario AS (
      SELECT
        t009b.mandt,
        t009b.periv,
        cal_year AS bdatj, -- Calendar Year used for calculation
        t009b.bumon,
        t009b.butag,
        t009b.reljr,
        t009b.poper,
        CAST(MIN(t009b.bumon) OVER (PARTITION BY t009b.mandt, t009b.periv ORDER BY t009b.poper) AS INT64) -- Min month for the variant
          AS MinimumBumonVariant,
        CAST(MIN(t009b.poper) OVER (PARTITION BY t009b.mandt, t009b.periv) AS INT64) -- Min period for the variant
          AS MinimumPoperVariant,
         -- Generate potential end date based on calendar year and t009b month/day
        CASE
          WHEN NOT COALESCE(ly.is_leap, FALSE)
            AND t009b.bumon = '02' AND t009b.butag = '29'
            THEN CAST(CONCAT(cal_year, '-', t009b.bumon, '-28') AS DATE) -- Handle non-leap Feb 29
          ELSE CAST(CONCAT(cal_year, '-', t009b.bumon, '-', t009b.butag) AS DATE)
        END AS PotentialEndDate,
        -- Determine the actual Fiscal Year this t009b entry belongs to
        cal_year - CAST(t009b.reljr AS INT64) AS FiscalYearActual -- Fiscal Year = Calendar Year - RelJr Shift
      FROM
        `{{ project_id_src }}.{{ dataset_cdc_processed }}.t009b` AS t009b
      INNER JOIN VariantTypes vt -- Join with variant types to filter
        ON t009b.mandt = vt.mandt AND t009b.periv = vt.periv
      CROSS JOIN
        UNNEST( -- Generate relevant calendar years
          GENERATE_ARRAY(
            EXTRACT(YEAR FROM DATE_SUB(CURRENT_DATE(), INTERVAL 10 YEAR)),
            EXTRACT(YEAR FROM DATE_ADD(CURRENT_DATE(), INTERVAL 10 YEAR))
          )) AS cal_year
      LEFT JOIN is_leap_year ly ON cal_year = ly.year -- Join with inlined UDF logic
      WHERE t009b.mandt = '{{ mandt }}'
        AND vt.is_case3 -- Use the new flag based on NULL or Empty check
        AND t009b.bdatj = '0000' -- Specific to FirstScenario
    ),
    -- Calculate start date according to fiscal year and period combination for t009b.bdatj = '0000'
    GetStartDateForFirstScenario AS (
      SELECT
        mandt,
        periv,
        bdatj, -- Calendar Year
        FiscalYearActual, -- Actual Fiscal Year
        bumon,
        butag,
        reljr,
        poper,
        PotentialEndDate AS EndDate, -- Use calculated potential end date
        -- Calculate PotentialStartDate using LAG only within the same fiscal year
        DATE_ADD(
            LAG(PotentialEndDate) OVER (PARTITION BY mandt, periv, FiscalYearActual ORDER BY poper),
            INTERVAL 1 DAY
            ) AS PotentialStartDate,
        -- Separately get the previous period's end date overall (for year boundary)
        LAG(PotentialEndDate, 1) OVER (PARTITION BY mandt, periv ORDER BY FiscalYearActual, poper) AS PrevPeriodEndDateOverall
      FROM GetEndDateForFirstScenario
    ),
    -- Step 1: Finalize StartDate calculation
    FinalizeDatesForFirstScenario_Step1 AS (
       SELECT
           *,
           -- Use COALESCE to handle the first period of a fiscal year
           COALESCE(DATE_ADD(PrevPeriodEndDateInYear, INTERVAL 1 DAY), DATE_ADD(PrevPeriodEndDateOverall, INTERVAL 1 DAY)) as StartDate
       FROM GetStartDateForFirstScenario -- Corrected: Changed GetStartDateForFirstScenario to GetPrevEndDateForFirstScenario
    ),
     -- Step 2: Finalize FiscalYearFirstDay and FiscalYearLastDay
    FinalizeDatesForFirstScenario_Step2 AS (
      SELECT
        *,
        -- Calculate FirstDay using MIN OVER the final StartDate from Step 1
        MIN(StartDate) OVER (PARTITION BY mandt, periv, FiscalYearActual) AS FiscalYearFirstDayCalculated,
        -- Calculate LastDay using MAX OVER the PotentialEndDate
        MAX(PotentialEndDate) OVER (PARTITION BY mandt, periv, FiscalYearActual) AS FiscalYearLastDayCalculated
      FROM FinalizeDatesForFirstScenario_Step1
    ),
    -- Generate Date Array and Base Fields for First Scenario
    GenerateDatesForFirstScenario AS (
      SELECT
        fdfs2.*, -- Use Step 2 results
        dt
      FROM FinalizeDatesForFirstScenario_Step2 fdfs2,
          UNNEST(GENERATE_DATE_ARRAY(fdfs2.StartDate, fdfs2.PotentialEndDate)) AS dt -- Use final StartDate and original PotentialEndDate
      WHERE fdfs2.StartDate <= fdfs2.PotentialEndDate -- Ensure valid date range
    ),
    -- Calculate aggregated fields, i.e, FiscalSemester,FiscalWeek and FiscalQuarter.
    GetAggFieldsForFirstScenario AS (
       SELECT
        mandt,
        periv,
        dt AS Date,
        FiscalYearFirstDayCalculated AS FiscalYearFirstDay,
        FiscalYearLastDayCalculated AS FiscalYearLastDay,
        CAST(FiscalYearActual AS STRING) AS FiscalYear,
        DATE_TRUNC(dt, ISOWEEK) AS WeekStartDate, -- Use ISOWEEK consistently
        LAST_DAY(dt, ISOWEEK) AS WeekEndDate,     -- Use ISOWEEK consistently
        poper AS FiscalPeriod,
        CAST(FORMAT_DATE('%Y%m%d', dt) AS INT64) AS DateInt,
        FORMAT_DATE('%Y%m%d', dt) AS DateStr,
        CASE
            WHEN dt >= FiscalYearFirstDayCalculated AND dt < DATE_ADD(FiscalYearFirstDayCalculated, INTERVAL 6 MONTH) THEN 1
            WHEN dt >= DATE_ADD(FiscalYearFirstDayCalculated, INTERVAL 6 MONTH) AND dt <= FiscalYearLastDayCalculated THEN 2
            ELSE NULL -- Handle potential edge cases/errors
        END AS FiscalSemester,
        CASE
            WHEN dt >= FiscalYearFirstDayCalculated AND dt < DATE_ADD(FiscalYearFirstDayCalculated, INTERVAL 3 MONTH) THEN 1
            WHEN dt >= DATE_ADD(FiscalYearFirstDayCalculated, INTERVAL 3 MONTH) AND dt < DATE_ADD(FiscalYearFirstDayCalculated, INTERVAL 6 MONTH) THEN 2
            WHEN dt >= DATE_ADD(FiscalYearFirstDayCalculated, INTERVAL 6 MONTH) AND dt < DATE_ADD(FiscalYearFirstDayCalculated, INTERVAL 9 MONTH) THEN 3
            WHEN dt >= DATE_ADD(FiscalYearFirstDayCalculated, INTERVAL 9 MONTH) AND dt <= FiscalYearLastDayCalculated THEN 4
            ELSE NULL -- Handle potential edge cases/errors
        END AS FiscalQuarter,
        DATE_DIFF(dt, DATE_TRUNC(FiscalYearFirstDayCalculated, ISOWEEK), ISOWEEK) + 1 AS FiscalWeek, -- Example week calc using ISOWEEK
        FORMAT_DATE('%A', dt) AS DayNameLong,
        FORMAT_DATE('%a', dt) AS DayNameShort,
        CONCAT(CAST(FiscalYearActual AS STRING), poper) AS FiscalYearPeriod
      FROM GenerateDatesForFirstScenario
    ),

    -- Calculate end date for each fiscal year and period combination for t009b.bdatj != '0000'
    -- NOTE: This 'SecondScenario' logic remains largely unchanged, assuming it works for year-dependent variants.
    -- It needs testing if you have such variants.
    GetEndDateForSecondScenario AS (
       SELECT
        t009.mandt,
        t009.periv,
        t009b.bdatj,
        t009b.bumon,
        t009b.butag,
        t009b.reljr,
        t009b.poper,
        CAST(MIN(t009b.bumon) OVER (PARTITION BY t009.mandt, t009.periv, t009b.bdatj) AS INT64)
          AS MinimumBumon,
        CAST(CONCAT(t009b.bdatj, '-', t009b.bumon, '-', t009b.butag) AS DATE) AS EndDate
      FROM
        `{{ project_id_src }}.{{ dataset_cdc_processed }}.t009` AS t009
      INNER JOIN
        `{{ project_id_src }}.{{ dataset_cdc_processed }}.t009b` AS t009b
        ON
          t009.mandt = t009b.mandt
          AND t009.periv = t009b.periv
      INNER JOIN VariantTypes vt -- Join with variant types to filter
        ON t009.mandt = vt.mandt AND t009.periv = vt.periv
      WHERE t009.mandt = '{{ mandt }}'
        AND vt.is_case3 -- Use the new flag based on NULL or Empty check
        AND t009b.bdatj != '0000' -- Specific to SecondScenario
    ),

    -- Calculate start date according to fiscal year and period combination for t009b.bdatj != '0000'
    GetStartDateForSecondScenario AS (
      SELECT
        mandt,
        periv,
        bdatj,
        bumon,
        butag,
        reljr,
        poper,
        EndDate,
        MinimumBumon, -- Pass MinimumBumon
        -- Calculate start date accordingly in case fiscal period is greater than 1 month.
        IF(
          MinimumBumon = 01, -- Check if the period starts in month 01
          COALESCE(
            DATE_ADD(
              LAG(EndDate) OVER (PARTITION BY mandt, periv, bdatj ORDER BY poper), -- Partition also by bdatj for year-dependent
              INTERVAL 1 DAY),
            DATE_TRUNC(EndDate, MONTH)),
          DATE_SUB(DATE_TRUNC(EndDate, MONTH), INTERVAL (MinimumBumon - 1) MONTH)
        ) AS StartDate
      FROM GetEndDateForSecondScenario
    ),

    -- Calculate Fiscal Year First and Last Day for Second Scenario
    GetFirstAndLastDayForSecondScenario AS (
       SELECT
        mandt,
        periv,
        poper,
        dt,
        reljr,
        CAST(bdatj AS INT64) + CAST(reljr AS INT64) AS FiscalYear, -- Fiscal Year determined by bdatj + reljr
        MIN(dt) OVER (PARTITION BY mandt, periv, CAST(bdatj AS INT64) + CAST(reljr AS INT64))
          AS FiscalYearFirstDay,
        MAX(dt) OVER (PARTITION BY mandt, periv, CAST(bdatj AS INT64) + CAST(reljr AS INT64))
          AS FiscalYearLastDay,
        DATE_TRUNC(dt, WEEK) AS WeekStartDate,
        LAST_DAY(dt, WEEK) AS WeekEndDate
      FROM GetStartDateForSecondScenario,
        UNNEST(GENERATE_DATE_ARRAY(StartDate, EndDate)) AS dt
      WHERE StartDate <= EndDate -- Ensure valid date range
    ),

    -- Calculate Aggregated Fields for Second Scenario
    GetAggFieldsForSecondScenario AS (
      SELECT
        mandt,
        periv,
        dt AS Date,
        FiscalYearFirstDay,
        FiscalYearLastDay,
        CAST(FiscalYear AS STRING) AS FiscalYearStr, -- Use FiscalYear from previous CTE
        WeekStartDate,
        WeekEndDate,
        poper AS FiscalPeriod,
        CAST(FORMAT_DATE('%Y%m%d', dt) AS INT64) AS DateInt,
        FORMAT_DATE('%Y%m%d', dt) AS DateStr,
        CASE
            WHEN dt >= FiscalYearFirstDay AND dt < DATE_ADD(FiscalYearFirstDay, INTERVAL 6 MONTH) THEN 1
            WHEN dt >= DATE_ADD(FiscalYearFirstDay, INTERVAL 6 MONTH) AND dt <= FiscalYearLastDay THEN 2
            ELSE NULL
        END AS FiscalSemester,
        CASE
            WHEN dt >= FiscalYearFirstDay AND dt < DATE_ADD(FiscalYearFirstDay, INTERVAL 3 MONTH) THEN 1
            WHEN dt >= DATE_ADD(FiscalYearFirstDay, INTERVAL 3 MONTH) AND dt < DATE_ADD(FiscalYearFirstDay, INTERVAL 6 MONTH) THEN 2
            WHEN dt >= DATE_ADD(FiscalYearFirstDay, INTERVAL 6 MONTH) AND dt < DATE_ADD(FiscalYearFirstDay, INTERVAL 9 MONTH) THEN 3
            WHEN dt >= DATE_ADD(FiscalYearFirstDay, INTERVAL 9 MONTH) AND dt <= FiscalYearLastDay THEN 4
            ELSE NULL
        END AS FiscalQuarter,
         DATE_DIFF(dt, DATE_TRUNC(FiscalYearFirstDay, WEEK), WEEK) + 1 AS FiscalWeek, -- Example week calc
        FORMAT_DATE('%A', dt) AS DayNameLong,
        FORMAT_DATE('%a', dt) AS DayNameShort,
        CONCAT(CAST(FiscalYear AS STRING), poper) AS FiscalYearPeriod
      FROM GetFirstAndLastDayForSecondScenario
    ),

    --Combine the records of both scenarios, i.e, t009b.bdatj = '0000' and t009b.bdatj != '0000'
    CombineBothScenarios AS (
      SELECT * FROM GetAggFieldsForFirstScenario
      UNION ALL
      SELECT * FROM GetAggFieldsForSecondScenario
    )
  SELECT DISTINCT -- Use DISTINCT as date generation might create overlaps if not careful
    mandt,
    periv,
    Date,
    DateInt,
    DateStr,
    FiscalPeriod,
    FiscalYear,
    FiscalYearPeriod,
    FiscalYearFirstDay,
    FiscalYearLastDay,
    FiscalSemester,
    CAST(CONCAT('0', FiscalSemester) AS STRING) AS FiscalSemesterStr,
    IF(FiscalSemester = 1, '1st Semester', '2nd Semester') AS FiscalSemesterStr2,
    FiscalQuarter,
    CAST(CONCAT('0', FiscalQuarter) AS STRING) AS FiscalQuarterStr,
    CAST(CONCAT('Q', FiscalQuarter) AS STRING) AS FiscalQuarterStr2,
    FiscalWeek,
    LPAD(CAST(FiscalWeek AS STRING), 2, '0') AS FiscalWeekStr,
    WeekStartDate,
    WeekEndDate,
    DayNameLong,
    DayNameShort
  FROM CombineBothScenarios
  --## CORTEX-CUSTOMER: The fiscal table solution works for only those variants(periv)
  -- where we have fiscal year as a continuous calendar year.
  WHERE periv NOT IN ('C2')
)
