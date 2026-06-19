INSERT INTO "WITH 
-- Очищаємо і перетворюємо дату реєстрації користувача у формат timestamp.
users_parsed AS (
    SELECT 
        user_id,
        signup_datetime,
        promo_signup_flag,
        CASE
           WHEN signup_datetime ~ '^\d{4}[-./]\d{1,2}[-./]\d{1,2}'
            	THEN TO_TIMESTAMP(REGEXP_REPLACE(signup_datetime,'[./]','-','g'),'YYYY-MM-DD HH24:MI')
           WHEN signup_datetime ~ '^\d{1,2}[-./]\d{1,2}[-./]\d{4}'
           		THEN TO_TIMESTAMP(REGEXP_REPLACE(signup_datetime,'[./]','-','g'),'DD-MM-YYYY HH24:MI')
           WHEN signup_datetime ~ '^\d{1,2}[-./]\d{1,2}[-./]\d{2}'
            	THEN TO_TIMESTAMP(REGEXP_REPLACE(signup_datetime,'[./]','-','g'),'DD-MM-YY HH24:MI')
        END AS signup_ts
    FROM cohort_users_raw
),
events_parsed AS (
    SELECT 
        event_id,
        user_id,
        event_type,
        CASE
            WHEN event_datetime ~ '^\d{4}[-./]\d{1,2}[-./]\d{1,2}'
            	THEN TO_TIMESTAMP(REGEXP_REPLACE(event_datetime,'[./]','-','g'),'YYYY-MM-DD HH24:MI')
           WHEN event_datetime ~ '^\d{1,2}[-./]\d{1,2}[-./]\d{4}'
           		THEN TO_TIMESTAMP(REGEXP_REPLACE(event_datetime,'[./]','-','g'),'DD-MM-YYYY HH24:MI')
           WHEN event_datetime ~ '^\d{1,2}[-./]\d{1,2}[-./]\d{2}'
            	THEN TO_TIMESTAMP(REGEXP_REPLACE(event_datetime,'[./]','-','g'),'DD-MM-YY HH24:MI')
            ELSE NULL
        END AS event_ts
    FROM cohort_events_raw
),
-- агрегуємо події до рівня user + month,зменшує кількість рядків перед JOIN.Пришвидшить
events_monthly AS (
    SELECT
        user_id,
        DATE_TRUNC('month', event_ts) AS activity_month
    FROM events_parsed
    WHERE
        event_ts IS NOT NULL
        AND event_type IS NOT NULL
        AND LOWER(event_type) != 'test_event'
    GROUP BY user_id, DATE_TRUNC('month', event_ts)
),
-- Об'єднання таблиць та побудова когортної таблиці
user_activity AS (
    SELECT 
        u.user_id,
        u.promo_signup_flag,
        e.activity_month,
--        DATE_TRUNC('month', e.event_ts) AS activity_month, 
		DATE_TRUNC('month', u.signup_ts)::date AS cohort_month,--Перетворити дати у формат рік-місяць
        EXTRACT(MONTH FROM AGE(DATE_TRUNC('month', e.activity_month),DATE_TRUNC('month', u.signup_ts))) month_offset --підійде тільки для датасету в якого один рік.
--        (EXTRACT(YEAR FROM e.event_ts) - EXTRACT(YEAR FROM u.signup_ts))* 12 +
--        (EXTRACT(MONTH FROM e.event_ts) - EXTRACT(MONTH FROM u.signup_ts)) AS month_offset
    FROM users_parsed u
    JOIN events_monthly e ON u.user_id = e.user_id
--     WHERE 
--        u.signup_ts IS NOT NULL
--        AND e.event_ts IS NOT NULL
--        AND e.event_type IS NOT NULL
--        AND LOWER(e.event_type) != 'test_event'
)
SELECT 
	promo_signup_flag,
	cohort_month, 
	month_offset,
	COUNT(DISTINCT user_id) AS user_total
FROM user_activity
WHERE activity_month BETWEEN '2025-01-01' AND '2025-06-01'
GROUP BY promo_signup_flag, cohort_month, month_offset
ORDER BY promo_signup_flag, cohort_month, month_offset" (promo_signup_flag,cohort_month,month_offset,user_total) VALUES
	 (0,'2025-01-01',0,70);
