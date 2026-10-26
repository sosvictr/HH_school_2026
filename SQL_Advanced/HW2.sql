-- ============================================================
-- Домашнее задание к лекции «SQL. Продвинутый»
-- Школа Аналитиков · учебная база hh_school
-- Автор: Иванова Виктория Владимировна
-- ============================================================

SET search_path TO hh_school;

-- ============================================================
-- БЛОК А. Качество и подготовка данных
-- ============================================================

-- ЗАДАНИЕ 1
-- 1) Пропуски
-- проверим пропуски в основных колонках vacancy_id, employer_id, call_at/sent_at

-- calls
SELECT COUNT(*) FILTER (WHERE vacancy_id IS NULL) AS null_vacancy_id,
       COUNT(*) FILTER (WHERE employer_id IS NULL) AS null_employer_id,
       COUNT(*) FILTER (WHERE call_at IS NULL) AS null_event_at
  FROM calls;

-- messages
SELECT COUNT(*) FILTER (WHERE vacancy_id IS NULL) AS null_vacancy_id,
       COUNT(*) FILTER (WHERE employer_id IS NULL) AS null_employer_id,
       COUNT(*) FILTER (WHERE sent_at IS NULL) AS null_event_at
  FROM messages;

-- Комментарий: эти значения необходимы для построения истории коммуникаций
-- по откликам. Пропуск в любой из этих колонок нарушал бы сам факт коммуникации,
-- и такую строку пришлось бы исключать из слоя. Проблемы в данных не найдено, поэтому 
-- ничего не исключается.

-- проверим пропуски в колонках, необходимых для других заданий

-- calls
SELECT COUNT(*) FILTER (WHERE caller_role IS NULL) AS null_role,
	   COUNT(*) FILTER (WHERE status IS NULL) AS null_status,
       COUNT(*) FILTER (WHERE status = 'successful'              -- интересуют только состоявишиеся звонки
                          AND call_duration IS NULL) AS null_duration_successful,
       COUNT(*) FILTER (WHERE call_tags IS NULL) AS null_call_tags
  FROM calls;

-- messages
SELECT COUNT(*) FILTER (WHERE sender_role IS NULL),
       COUNT(*) FILTER (WHERE message_meta IS NULL)
  FROM messages;

-- Комментарий: Пропуск в них не отменяет факт коммуникации, а влияет только 
-- на метрики по самой колонке (длительность звонков, каналы, прочтения, вложения, теги).
-- Такие строки остаются в слое событий и исключаются только из расчёта соответствующего показателя.
-- Оговорка: проверка call_tags и message_meta примитивная, она ловит только NULL. 
-- Пустой массив тегов или пустой объект метаданных она не обнаружит. Такие значения
-- формально не NULL, но полезной информации не несут.


-- 2) Отсутствие связи с откликом (такого отклика нет в responses, либо поле не заполнено (NULL))

-- calls
SELECT COUNT(*) AS call_cnt_with_no_response
  FROM calls c
 WHERE NOT EXISTS (
         SELECT r.response_id
           FROM responses r
          WHERE r.response_id = c.response_id -- так операция = с null не определена, такие строки также исключаются
       );
	   
SELECT c.call_id
  FROM calls c
 WHERE NOT EXISTS (
         SELECT r.response_id
           FROM responses r
          WHERE r.response_id = c.response_id
	   );

-- messages
SELECT COUNT(*) AS msg_cnt_with_no_response
  FROM messages m
 WHERE NOT EXISTS (
         SELECT r.response_id
           FROM responses r
          WHERE r.response_id = m.response_id
       );
	   
SELECT m.message_id
  FROM messages m
 WHERE NOT EXISTS (
         SELECT r.response_id
           FROM responses r
          WHERE r.response_id = m.response_id
       );
	   
-- Комментарий: 
-- Проблема затрагивает сам факт коммуникации. Коммуникацию нельзя
-- отнести ни к какому отклику. ... Такие строки исключаем.

-- 3) Согласованность данных внутри таблицы (нет противоречий)

-- в коммуникациях поля с данными о вакансии и отклике заполнены верно

-- calls
SELECT COUNT(*) FILTER (WHERE c.employer_id <> v.employer_id) AS cnt_employer, -- совпадает ли имя работодателя у вакансии
       COUNT(*) FILTER (WHERE r.resume_id <> c.applicant_id) AS cnt_applicant -- совпадает ли номер откликающегося на вакансию
  FROM calls c
  	   JOIN responses r 
	   ON r.response_id = c.response_id
  	   JOIN vacancies v 
	   ON v.vacancy_id = r.vacancy_id;

SELECT c.call_id
  FROM calls c
  	   JOIN responses r 
	   ON r.response_id = c.response_id
  	   JOIN vacancies v 
	   ON v.vacancy_id = r.vacancy_id
 WHERE c.employer_id <> v.employer_id
    OR r.resume_id <> c.applicant_id;

-- messages
SELECT COUNT(*) FILTER (WHERE m.employer_id <> v.employer_id) AS cnt_employer,
       COUNT(*) FILTER (WHERE r.resume_id <> m.applicant_id) AS cnt_applicant
  FROM messages m
  	   JOIN responses r 
	   ON r.response_id = m.response_id
  	   JOIN vacancies v 
	   ON v.vacancy_id = r.vacancy_id;

SELECT m.message_id
  FROM messages m
  	   JOIN responses r 
	   ON r.response_id = m.response_id
  	   JOIN vacancies v 
	   ON v.vacancy_id = r.vacancy_id
 WHERE m.employer_id <> v.employer_id
    OR r.resume_id <> m.applicant_id;

-- Комментарий: Если данные по коммуникаци, отклику и информации о вакансии 
-- не согласуются между собой, проблема влияет на факт коммуникации, поскольку ...
-- Такие строки пришлось бы исключать. Проблемы в данных не найдено, поэтому 
-- ничего не исключается.

-- 4) Временные аномалии

-- calls
SELECT COUNT(*) AS cnt_before_response,
  FROM calls c
  	   JOIN responses r 
	   ON r.response_id = c.response_id -- смотрим только из тех, что в откликах
 WHERE  r.created_at > c.call_at;

SELECT c.call_id
  FROM calls c
  	   JOIN responses r 
	   ON r.response_id = c.response_id
 WHERE  r.created_at > c.call_at;

-- messages
SELECT COUNT(*) AS cnt_before_response
  FROM messages m
  	   JOIN responses r 
	   ON r.response_id = m.response_id
 WHERE  r.created_at > m.sent_at;

SELECT m.message_id
  FROM messages m
  	   JOIN responses r 
	   ON r.response_id = m.response_id
 WHERE  r.created_at > m.sent_at;

-- Комменатрий: 
-- Такая аномалия затрагивала бы сам факт коммуникации
-- (событие до отклика не может быть реакцией на него), и такие
-- строки пришлось бы исключать. Проблемы в данных не найдено, поэтому 
-- ничего не исключается.

-- исследование call_duration
WITH p AS (
  SELECT PERCENTILE_CONT(0.99) WITHIN GROUP (ORDER BY call_duration) AS p99
    FROM calls
   WHERE status = 'successful'
)
SELECT AVG(c.call_duration) AS avg_with_outliers,
	   PERCENTILE_CONT(0.5)  WITHIN GROUP (ORDER BY call_duration) AS p50_sec,
	   PERCENTILE_CONT(0.99) WITHIN GROUP (ORDER BY call_duration) AS p99,
	   COUNT(*) FILTER (WHERE c.call_duration >  p.p99) AS cnt_above_p99,
	   AVG(c.call_duration) FILTER (WHERE c.call_duration <= p.p99) AS avg_without_outliers
  FROM calls c
 CROSS JOIN p
 WHERE status = 'successful';


-- Вывод: 
-- Был проведен анализ качества данных. Из предложенных проверок проверка проблемы 2 (связь коммуникации с откликом) 
-- показала, что целесообразно сключить из слоя коммуникаций: calls — 8 строк.

-- После удаления 2 значений, больших p99, среднее сместилось ненамного. 
-- К тому же, для всей выборки медиана и среднее отличаются примерно на 6%. 
-- Это не такой критичный разрыв, как если бы были реально нетипичные значения.
-- Думаю, это допустимые значения, а не ошибки. Можно оставить их при расчёте 
-- типичной длительности звонка.

-- ============================================================
-- БЛОК Б. Качество и подготовка данных
-- ============================================================

-- ЗАДАНИЕ 2. 
-- как я поняла, нужны события, инициированные работодателем

WITH valid_calls AS (
  SELECT r.response_id,
         c.employer_id,
         c.call_id   AS event_id,
         c.call_at   AS event_at,
         'call'      AS event_type
    FROM calls c
         JOIN responses r 
		 ON r.response_id = c.response_id
   WHERE c.caller_role = 'employer'
   	 AND c.call_at < r.created_at + INTERVAL '7 days'
),

valid_messages AS (
  SELECT r.response_id,
         m.employer_id,
         m.message_id AS event_id,
         m.sent_at AS event_at,
         'message' AS event_type
    FROM messages m
    	 JOIN responses r 
		 ON r.response_id = m.response_id
    	 JOIN vacancies v 
		 ON v.vacancy_id  = r.vacancy_id
   WHERE m.sender_role = 'employer'
     AND m.sent_at < r.created_at + INTERVAL '7 days'
),

events AS (
  SELECT * FROM valid_calls
  UNION ALL
  SELECT * FROM valid_messages
)

-- проверка
-- SELECT response_id,
--        employer_id,
--        event_id,
--        event_at,
--        event_type
--   FROM events
--   ORDER BY response_id, employer_id;

SELECT COUNT(*) AS total_cnt,
	   COUNT(DISTINCT response_id) AS response_cnt,
	   COUNT(*) FILTER (WHERE event_type = 'message') AS msg_cnt,
	   COUNT(*) FILTER (WHERE event_type = 'call') AS call_cnt
  FROM events;

-- Вывод: 
-- общее количество событий: 1096
-- количество различных откликов с коммуникацией: 382
-- количество звонков: 108
-- количество сообщений: 988

-- ЗАДАНИЕ 3. Таймлайн коммуникаций и витрина отклика

WITH valid_calls AS (
  SELECT r.response_id,
         c.employer_id,
         c.call_id   AS event_id,
         c.call_at   AS event_at,
         'call'      AS event_type
    FROM calls c
    	 JOIN responses r 
		 ON r.response_id = c.response_id
   WHERE c.caller_role = 'employer'
   	 AND c.call_at < r.created_at + INTERVAL '7 days'
),

valid_messages AS (
  SELECT r.response_id,
         m.employer_id,
         m.message_id AS event_id,
         m.sent_at    AS event_at,
         'message'    AS event_type
    FROM messages m
    	 JOIN responses r 
		 ON r.response_id = m.response_id
    	 JOIN vacancies v 
		 ON v.vacancy_id  = r.vacancy_id
   WHERE m.sender_role = 'employer'
     AND m.sent_at < r.created_at + INTERVAL '7 days'
),

events AS (
  SELECT * FROM valid_calls
  UNION ALL
  SELECT * FROM valid_messages
),

timeline AS (
  SELECT response_id,
         employer_id,
         event_id,
         event_at,
         event_type	 
    FROM events
   ORDER BY response_id, event_at, event_id
),

timeline_with_layers AS (
  SELECT *,
         ROW_NUMBER() OVER w AS event_num,
         LAG(event_at) OVER w AS prev_event_at,
         LEAD(event_type) OVER w AS next_event_type,
         COUNT(*) OVER (w ROWS BETWEEN UNBOUNDED PRECEDING
                                   AND CURRENT ROW) AS comm_cnt_to_date,
         FIRST_VALUE(event_type) OVER w AS first_event_type,
         LAST_VALUE(event_type) OVER (w ROWS BETWEEN UNBOUNDED PRECEDING
                                               AND UNBOUNDED FOLLOWING) AS last_event_type
  FROM timeline
 WINDOW w AS (
    PARTITION BY response_id
    ORDER BY event_type, event_id
  )

SELECT *
  FROM timeline_with_layers;


-- шаг 2
WITH valid_calls AS (
  SELECT r.response_id,
         c.employer_id,
         c.call_id   AS event_id,
         c.call_at   AS event_at,
         'call'      AS event_type
    FROM calls c
    JOIN responses r ON r.response_id = c.response_id
   WHERE c.caller_role = 'employer'
   	 AND c.call_at < r.created_at + INTERVAL '7 days'
),

valid_messages AS (
  SELECT r.response_id,
         m.employer_id,
         m.message_id AS event_id,
         m.sent_at    AS event_at,
         'message'    AS event_type
    FROM messages m
    JOIN responses r ON r.response_id = m.response_id
    JOIN vacancies v ON v.vacancy_id  = r.vacancy_id
   WHERE m.sender_role = 'employer'
     AND m.sent_at < r.created_at + INTERVAL '7 days'
),

events AS (
  SELECT * FROM valid_calls
  UNION ALL
  SELECT * FROM valid_messages
),

timeline AS (
  SELECT response_id,
         employer_id,
         event_id,
         event_at,
         event_type	 
    FROM events
   ORDER BY response_id, event_at, event_id
),

timeline_with_layers AS (
  SELECT *,
         ROW_NUMBER() OVER w AS event_num,
         LAG(event_at) OVER w AS prev_event_at,
         LEAD(event_type) OVER w AS next_event_type,
         COUNT(*) OVER (w ROWS BETWEEN UNBOUNDED PRECEDING
                                   AND CURRENT ROW) AS comm_cnt_to_date,
         FIRST_VALUE(event_type) OVER w AS first_event_type,
         LAST_VALUE(event_type) OVER (w ROWS BETWEEN UNBOUNDED PRECEDING
                                               AND UNBOUNDED FOLLOWING) AS last_event_type
  FROM timeline
 WINDOW w AS (
    PARTITION BY response_id
    ORDER BY event_type, event_id
  )

response_comm AS (
  SELECT response_id,
         COUNT(*) AS comm_cnt,
         COUNT(*) FILTER (WHERE event_type = 'call') AS call_cnt,
         COUNT(*) FILTER (WHERE event_type = 'message') AS msg_cnt,
         MIN(event_at) AS first_comm_at,
         MAX(event_type) FILTER (WHERE event_num = 1) AS first_comm_type,
         MAX(event_type) FILTER (WHERE event_num = 2) AS second_comm_type,
         MAX(last_event_type) AS last_comm_type,
         MAX(EXTRACT(EPOCH FROM event_at - prev_event_at)) / 3600
                                                        AS max_gap_hours
    FROM timeline_with_layers
   GROUP BY response_id
),

response_mart AS (
  SELECT r.response_id,
         v.employer_id,
         v.professional_role,
         r.status                          AS response_status,
         COALESCE(rc.comm_cnt, 0)          AS comm_cnt,
         COALESCE(rc.call_cnt, 0)          AS call_cnt,
         COALESCE(rc.msg_cnt, 0)           AS msg_cnt,
         rc.first_comm_at,
         rc.first_comm_type,
         rc.second_comm_type,
         rc.last_comm_type,
         EXTRACT(EPOCH FROM rc.first_comm_at - r.created_at) / 3600
                                           AS hours_to_first_comm,
         rc.max_gap_hours
    FROM responses r
    LEFT JOIN vacancies v ON v.vacancy_id   = r.vacancy_id
    LEFT JOIN response_comm rc ON rc.response_id = r.response_id
)

SELECT COUNT(*)                                             AS total_rows,
       COUNT(*) FILTER (WHERE comm_cnt > 0)                 AS with_comm,
       COUNT(*) FILTER (WHERE comm_cnt = 0)                 AS without_comm,
       COUNT(*) FILTER (WHERE first_comm_type = 'message')  AS first_msg,
       COUNT(*) FILTER (WHERE first_comm_type = 'call')     AS first_call
  FROM response_mart;


 -- 4
 WITH
  -- ... все CTE из заданий 2-3 до response_mart включительно ...
  response_mart AS (...),

employer_stats AS (
  SELECT professional_role,
         employer_id,
         COUNT(*)                                                  AS resp_cnt,
         COUNT(*) FILTER (WHERE comm_cnt > 0)                      AS processed_cnt,
         100.0 * COUNT(*) FILTER (WHERE comm_cnt > 0) / COUNT(*)   AS processed_pct,
         PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY hours_to_first_comm) AS median_hours,
         PERCENTILE_CONT(0.9) WITHIN GROUP (ORDER BY hours_to_first_comm) AS p90_hours,
         100.0 * COUNT(*) FILTER (WHERE response_status = 'invited') / COUNT(*) AS invite_pct
    FROM response_mart
   GROUP BY professional_role, employer_id
  HAVING COUNT(*) >= 8
),

ranked AS (
  SELECT *,
         DENSE_RANK() OVER (
           PARTITION BY professional_role
           ORDER BY processed_pct DESC, median_hours ASC
         ) AS place
    FROM employer_stats
)

SELECT professional_role,
       place,
       employer_id,
       resp_cnt,
       processed_cnt,
       ROUND(processed_pct, 1)          AS processed_pct,
       ROUND(median_hours::NUMERIC, 1)  AS median_hours,
       ROUND(p90_hours::NUMERIC, 1)     AS p90_hours,
       ROUND(invite_pct, 1)             AS invite_pct
  FROM ranked
 WHERE place <= 2
 ORDER BY professional_role, place, employer_id;