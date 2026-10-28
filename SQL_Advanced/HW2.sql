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

-- Комментарий: 
-- vacancy_id, employer_id и время события — базис коммуникации:
-- без них нельзя сказать, кто, по какой вакансии и когда связался с кандидатом,
-- а значит, нельзя поставить событие в таймлайн отклика и посчитать время реакции.
-- Пропуск в любой из этих колонок нарушал бы сам факт коммуникации,
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

-- Комментарий: 
-- Пропуск в них не отменяет факт коммуникации, а влияет только 
-- на метрики по самой колонке (длительность звонков, каналы, прочтения, вложения, теги).
-- Такие строки остаются в слое событий и исключаются только из расчёта соответствующего показателя.
-- Проблемы в данных не найдено, поэтому ничего не исключается.
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
	   
SELECT c.call_id,
	   c.status,
	   c.caller_role
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
-- Найдено 8 звонков без отклика, у всех response_id IS NULL. Сообщений без отклика — 0.
-- Все 8 — исходящие звонки работодателя (5 unsuccessful, 3 successful).
-- Проблема затрагивает сам факт коммуникации: без response_id звонок нельзя однозначно
-- привязать к отклику и учесть в витрине.

-- можно ли восстановить связь по паре вакансия + кандидат
SELECT c.call_id,
       c.call_at,
       r.response_id,
       r.created_at,
       c.call_at < r.created_at AS is_before_response
  FROM calls c
       JOIN responses r
       ON r.vacancy_id = c.vacancy_id
       AND r.resume_id = c.applicant_id
 WHERE c.response_id IS NULL;

-- Попытка восстановить связь по vacancy_id + applicant_id показала: каждому звонку
-- соответствует отклик, но все 8 звонков состоялись до создания этого отклика,
-- то есть реакцией на отклик они не являются. Такие строки исключаем.

-- 3) Согласованность данных между таблицами (нет противоречий)

-- в коммуникациях поля с данными о вакансии и отклике заполнены верно

-- calls
SELECT COUNT(*) FILTER (WHERE c.employer_id <> v.employer_id) AS cnt_employer, -- совпадает ли имя работодателя у вакансии
       COUNT(*) FILTER (WHERE r.resume_id <> c.applicant_id) AS cnt_applicant -- совпадает ли номер откликающегося на вакансию
  FROM calls c
  	   JOIN responses r 
	   ON r.response_id = c.response_id
  	   JOIN vacancies v 
	   ON v.vacancy_id = r.vacancy_id;

-- messages
SELECT COUNT(*) FILTER (WHERE m.employer_id <> v.employer_id) AS cnt_employer,
       COUNT(*) FILTER (WHERE r.resume_id <> m.applicant_id) AS cnt_applicant
  FROM messages m
  	   JOIN responses r 
	   ON r.response_id = m.response_id
  	   JOIN vacancies v 
	   ON v.vacancy_id = r.vacancy_id;

-- Комментарий: 
-- Проверяем, что работодатель в событии совпадает с владельцем вакансии,
-- а кандидат — с автором резюме из отклика. При расхождении событие могло быть
-- привязано к чужому отклику и исказило бы и таймлайн отклика, и метрики работодателя,
-- поэтому такие строки пришлось бы исключать. Проблемы в данных не найдено, поэтому 
-- ничего не исключается.

-- 4) Временные аномалии

-- calls
SELECT COUNT(*) AS cnt_before_response
  FROM calls c
  	   JOIN responses r 
	   ON r.response_id = c.response_id -- смотрим только из тех, что в откликах
 WHERE  r.created_at > c.call_at;

-- messages
SELECT COUNT(*) AS cnt_before_response
  FROM messages m
  	   JOIN responses r 
	   ON r.response_id = m.response_id
 WHERE  r.created_at > m.sent_at;

-- Комменатрий: 
-- Такая аномалия затрагивала бы сам факт коммуникации
-- (событие до отклика не может быть реакцией на него), и такие
-- строки пришлось бы исключать. Проблемы в данных не найдено, поэтому 
-- ничего не исключается.

-- 5) Нетипичные значения
-- какие значения вообще встречаются в категориальных полях
SELECT 'calls.caller_role' AS field, 
	   caller_role AS value, 
	   COUNT(*) AS cnt
  FROM calls
 GROUP BY caller_role
 
UNION ALL

SELECT 'calls.status', 
	   status, 
	   COUNT(*)
  FROM calls
 GROUP BY status
 
UNION ALL

SELECT 'calls.call_tags', 
	   tag, 
	   COUNT(*)
  FROM calls
       CROSS JOIN UNNEST(call_tags) AS tag
 GROUP BY tag
 
UNION ALL

SELECT 'messages.sender_role', 
	   sender_role, 
	   COUNT(*)
  FROM messages
 GROUP BY sender_role
 
UNION ALL

SELECT 'messages.channel', 
	   COALESCE(message_meta ->> 'channel', '<нет ключа>'), 
	   COUNT(*)
  FROM messages
 GROUP BY COALESCE(message_meta ->> 'channel', '<нет ключа>')
 
UNION ALL

SELECT 'messages.is_read', 
	   COALESCE(message_meta ->> 'is_read', '<нет ключа>'), 
	   COUNT(*)
  FROM messages
 GROUP BY COALESCE(message_meta ->> 'is_read', '<нет ключа>')
 ORDER BY field, cnt DESC;

-- Комментарий: посторонних значений нет. Роли — только employer/applicant, статусы —
-- successful/unsuccessful/error, в тегах 10 ожидаемых, у сообщения
-- есть channel (web/mobile_app) и is_read (true/false). Единственный редкий
-- статус error (1 звонок) — допустимое значение. Нетипичные значения в этих полях
-- не затрагивают сам факт коммуникации, а касаются только отдельных атрибутов. 
-- Они остаются в слое и при необходимости исключаются только из расчёта
-- соответствующего показателя

-- исследование call_duration
WITH p AS (
  SELECT PERCENTILE_CONT(0.99) WITHIN GROUP (ORDER BY call_duration) AS p99
    FROM calls
   WHERE status = 'successful'
)
SELECT ROUND(AVG(c.call_duration), 1) AS avg_with_outliers,
	   PERCENTILE_CONT(0.5)  WITHIN GROUP (ORDER BY call_duration) AS p50_sec,
	   PERCENTILE_CONT(0.99) WITHIN GROUP (ORDER BY call_duration) AS p99,
	   COUNT(*) FILTER (WHERE c.call_duration >  p.p99) AS cnt_above_p99,
	   ROUND(AVG(c.call_duration) FILTER (WHERE c.call_duration <= p.p99), 1) AS avg_without_outliers
  FROM calls c
 CROSS JOIN p
 WHERE status = 'successful';


-- Вывод: 
-- Был проведен анализ качества данных. Единственная выявленная проблема, затрагивающая 
-- сам факт коммуникации, — 8 звонков без response_id, исключаем их из слоя коммуникаций. Пропусков,
-- расхождений идентификаторов, событий раньше отклика и противоречий внутри строки
-- не найдено.

-- При анализе длительности успешеых звонков получили: 
-- средняя длительность: 467,3 с
-- медиана: 438 с
-- 99-й перцентиль: 890,4 с
-- количество звонков выше 99-го перцентиля: 2
-- средняя длительность без значений выше 99-го перцентиля: 462,5 с
-- После исключения 2 значений выше p99 среднее сместилось ненамного (с 467,3 до 462,5 с). 
-- К тому же, для всей выборки медиана и среднее отличаются примерно на 6%. 
-- Это не такой критичный разрыв, как если бы были реально нетипичные значения.
-- Думаю, это допустимые значения, а не ошибки, от p99 они отличаются меньше
-- чем на 10 секунд. Можно оставить их при расчёте типичной длительности звонка.

-- ============================================================
-- БЛОК Б. История коммуникаций
-- ============================================================

-- ЗАДАНИЕ 2. 
-- нужны события, инициированные работодателем

WITH valid_calls AS (
  SELECT c.response_id,
         c.employer_id,
         c.call_id AS event_id,
         c.call_at AS event_at,
         'call' AS event_type
    FROM calls c
         JOIN responses r 
		 ON r.response_id = c.response_id
   WHERE c.caller_role = 'employer'
   	 AND c.call_at < r.created_at + INTERVAL '7 days'
),

valid_messages AS (
  SELECT m.response_id,
         m.employer_id,
         m.message_id AS event_id,
         m.sent_at AS event_at,
         'message' AS event_type
    FROM messages m
    	 JOIN responses r 
		 ON r.response_id = m.response_id
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

-- Комментарийй: 
-- общее количество событий: 1096
-- количество различных откликов с коммуникацией: 382
-- количество звонков: 108
-- количество сообщений: 988

-- Вывод: за первые 7 дней работодатели связались с кандидатами по более половины откликам 
-- (382 откликам из 628 (около 61%)).
-- Основной канал — сообщения: 988 событий (около 90%) против 108 звонков (около 10%), то есть
-- работодатели предпочитают переписку, а звонок служит дополнительным инструментом.

-- ЗАДАНИЕ 3. Таймлайн коммуникаций и витрина отклика

WITH valid_calls AS (
  SELECT c.response_id,
         c.employer_id,
         c.call_id AS event_id,
         c.call_at AS event_at,
         'call' AS event_type
    FROM calls c
         JOIN responses r 
		 ON r.response_id = c.response_id
   WHERE c.caller_role = 'employer'
   	 AND c.call_at < r.created_at + INTERVAL '7 days'
),

valid_messages AS (
  SELECT m.response_id,
         m.employer_id,
         m.message_id AS event_id,
         m.sent_at AS event_at,
         'message' AS event_type
    FROM messages m
    	 JOIN responses r 
		 ON r.response_id = m.response_id
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
         event_type,
		 ROW_NUMBER() OVER w AS event_num,
         LAG(event_at) OVER w AS prev_event_at,
         LEAD(event_type) OVER w AS next_event_type,
         COUNT(*) OVER (w ROWS BETWEEN UNBOUNDED PRECEDING
                                   AND CURRENT ROW) AS event_cnt_to_current,
         FIRST_VALUE(event_type) OVER w AS first_event_type,
         LAST_VALUE(event_type) OVER (w ROWS BETWEEN UNBOUNDED PRECEDING
                                                 AND UNBOUNDED FOLLOWING) AS last_event_type
    FROM events
   WINDOW w AS (
    PARTITION BY response_id
    ORDER BY event_at, event_type, event_id
   )
   ORDER BY response_id, event_at, event_type, event_id
)

-- проверка количества коммуникаций для шага 2
-- SELECT event_type AS first_comm_type,
--        COUNT(DISTINCT response_id) AS response_cnt
--   FROM timeline
--  WHERE event_num = 1
--  GROUP BY event_type
--  ORDER BY event_type;


SELECT response_id,
	   employer_id,
	   event_id,
       event_at,
       event_type,
	   event_num,
	   prev_event_at,
	   next_event_type,
	   event_cnt_to_current,
	   first_event_type,
	   last_event_type
  FROM timeline;


-- шаг 2

WITH valid_calls AS (
  SELECT c.response_id,
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
  SELECT m.response_id,
         m.employer_id,
         m.message_id AS event_id,
         m.sent_at    AS event_at,
         'message'    AS event_type
    FROM messages m
    	 JOIN responses r 
		 ON r.response_id = m.response_id
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
         event_type,
		 ROW_NUMBER() OVER w AS event_num,
         LAG(event_at) OVER w AS prev_event_at,
         LEAD(event_type) OVER w AS next_event_type,
         COUNT(*) OVER (w ROWS BETWEEN UNBOUNDED PRECEDING
                                   AND CURRENT ROW) AS event_cnt_to_current,
         FIRST_VALUE(event_type) OVER w AS first_event_type,
         LAST_VALUE(event_type) OVER (w ROWS BETWEEN UNBOUNDED PRECEDING
                                                 AND UNBOUNDED FOLLOWING) AS last_event_type
    FROM events
   WINDOW w AS (
    PARTITION BY response_id
    ORDER BY event_at, event_type, event_id
   )
   ORDER BY response_id, event_at, event_type, event_id
),

gaps AS (
  SELECT response_id,
         event_id,
         ROUND(
           (DATE_PART('epoch', event_at - prev_event_at) / 3600)::NUMERIC, 2) AS time_from_previous
    FROM timeline
),

response_mart AS (
	SELECT r.response_id,
	       v.employer_id,
	       v.professional_role,
	       r.status AS response_status,
	       COUNT(t.event_id) AS comm_cnt,
	       COUNT(t.event_id) FILTER (WHERE t.event_type = 'call') AS call_cnt,
	       COUNT(t.event_id) FILTER (WHERE t.event_type = 'message') AS msg_cnt,
	       MIN(t.event_at) AS first_comm_at,
	       MIN(t.event_type) FILTER (WHERE t.event_num = 1) AS first_comm_type,
	       MIN(t.event_type) FILTER (WHERE t.event_num = 2) AS second_comm_type,
	       MAX(t.last_event_type) AS last_comm_type,
	       ROUND(
	           (DATE_PART('epoch', MIN(t.event_at) - r.created_at) / 3600)::NUMERIC,
	           2
	         ) AS hours_to_first_comm, 
		   MAX(g.time_from_previous) AS max_gap_hours
	  FROM responses r
	  	   JOIN vacancies v  
			 ON v.vacancy_id = r.vacancy_id
	  	   LEFT JOIN timeline t 
			      ON t.response_id = r.response_id
	 	   LEFT JOIN gaps g     
				  ON g.response_id = t.response_id
	              AND g.event_id = t.event_id
	 GROUP BY r.response_id, v.employer_id, v.professional_role, r.status, r.created_at
)

SELECT COUNT(*) AS total_rows,
       COUNT(*) FILTER (WHERE comm_cnt > 0) AS with_comm,
       COUNT(*) FILTER (WHERE comm_cnt = 0) AS without_comm,
       COUNT(*) FILTER (WHERE first_comm_type = 'message') AS first_msg,
       COUNT(*) FILTER (WHERE first_comm_type = 'call') AS first_call
  FROM response_mart;

-- Комментарий:
-- количество строк: 628;
-- количество откликов с коммуникацией: 382;
-- количество откликов без коммуникации: 246;
-- количество откликов, где первой коммуникацией было сообщение: 314;
-- количество откликов, где первой коммуникацией был звонок: 68

-- Вывод: 246 откликов из 628 (около 39%) остались без реакции работодателя в первую неделю,
-- и это заметная доля кандидатов без обратной связи. Если работодатель выходит на связь,
-- то в 82% случаев (314 из 382) он начинает с сообщения и лишь в 18% (68) — со звонка:
-- первый контакт почти всегда письменный.


-- ============================================================
-- БЛОК В. Сравнение работодателей
-- ============================================================

-- ЗАДАНИЕ 4

WITH valid_calls AS (
  SELECT c.response_id,
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
  SELECT m.response_id,
         m.employer_id,
         m.message_id AS event_id,
         m.sent_at    AS event_at,
         'message'    AS event_type
    FROM messages m
    	 JOIN responses r 
		 ON r.response_id = m.response_id
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
         event_type,
		 ROW_NUMBER() OVER w AS event_num,
         LAG(event_at) OVER w AS prev_event_at,
         LEAD(event_type) OVER w AS next_event_type,
         COUNT(*) OVER (w ROWS BETWEEN UNBOUNDED PRECEDING
                                   AND CURRENT ROW) AS event_cnt_to_current,
         FIRST_VALUE(event_type) OVER w AS first_event_type,
         LAST_VALUE(event_type) OVER (w ROWS BETWEEN UNBOUNDED PRECEDING
                                                 AND UNBOUNDED FOLLOWING) AS last_event_type
    FROM events
   WINDOW w AS (
    PARTITION BY response_id
    ORDER BY event_at, event_type, event_id
   )
   ORDER BY response_id, event_at, event_type, event_id
),

gaps AS (
  SELECT response_id,
         event_id,
         ROUND(
           (DATE_PART('epoch', event_at - prev_event_at) / 3600)::NUMERIC,
           2
         ) AS time_from_previous
    FROM timeline
),

response_mart AS (
	SELECT r.response_id,
	       v.employer_id,
	       v.professional_role,
	       r.status AS response_status,
	       COUNT(t.event_id) AS comm_cnt,
	       COUNT(t.event_id) FILTER (WHERE t.event_type = 'call') AS call_cnt,
	       COUNT(t.event_id) FILTER (WHERE t.event_type = 'message') AS msg_cnt,
	       MIN(t.event_at) AS first_comm_at,
	       MIN(t.event_type) FILTER (WHERE t.event_num = 1) AS first_comm_type,
	       MIN(t.event_type) FILTER (WHERE t.event_num = 2) AS second_comm_type,
	       MAX(t.last_event_type) AS last_comm_type,
	       ROUND(
	           (DATE_PART('epoch', MIN(t.event_at) - r.created_at) / 3600)::NUMERIC,
	           2
	         ) AS hours_to_first_comm, 
		   MAX(g.time_from_previous) AS max_gap_hours
	  FROM responses r
	  	   JOIN vacancies v  
			 ON v.vacancy_id = r.vacancy_id
	  	   LEFT JOIN timeline t 
			      ON t.response_id = r.response_id
	 	   LEFT JOIN gaps g     
				  ON g.response_id = t.response_id
	              AND g.event_id = t.event_id
	 GROUP BY r.response_id, v.employer_id, v.professional_role, r.status, r.created_at
),

employer_stats AS (
  SELECT professional_role,
         rm.employer_id,
		 e.employer_name,
         COUNT(*) AS resp_cnt,
         COUNT(*) FILTER (WHERE comm_cnt > 0) AS processed_cnt,
         100.0 * COUNT(*) FILTER (WHERE comm_cnt > 0) 
		 	   / NULLIF(COUNT(*), 0) AS processed_pct,
         PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY hours_to_first_comm) AS median_hours,
         PERCENTILE_CONT(0.9) WITHIN GROUP (ORDER BY hours_to_first_comm) AS p90_hours,
         100.0 * COUNT(*) FILTER (WHERE response_status = 'invited') 
		 	   / NULLIF(COUNT(*), 0) AS conversion_pct
    FROM response_mart rm
	LEFT JOIN employers e
	       ON rm.employer_id = e.employer_id
   GROUP BY professional_role, rm.employer_id, e.employer_name
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
	   employer_id,
	   employer_name,
       place,
       resp_cnt,
       processed_cnt,
       ROUND(processed_pct, 1) AS processed_pct,
       ROUND(median_hours::NUMERIC, 2) AS median_hours,
       ROUND(p90_hours::NUMERIC, 2) AS p90_hours,
       ROUND(conversion_pct, 1) AS conversion_pct
  FROM ranked
 WHERE place <= 2
 ORDER BY professional_role, place, employer_id;

-- Комментарий:
-- "Аналитик данных"		1	109
-- "Аналитик данных"		2	103
-- "Дата-инженер"			1	106
-- "Дата-инженер"			2	101
-- "Продуктовый аналитик"	1	103
-- "Продуктовый аналитик"	2	102
-- "Разработчик"			1	112
-- "Разработчик"			2	104
-- "Тестировщик"			1	107
-- "Тестировщик"			2	108

-- Вывод: у лидеров направлений доля обработанных откликов — от 70,0% до 89,5%, 
-- а разрыв со 2-м местом бывает большим (Дата-инженер: 70,0% против 45,8%). 
-- Высокая доля обработки не гарантирует приглашений:
-- у 103 в аналитике данных обработано 84,8% откликов, но конверсия лишь 10,1%,
-- тогда как у лидеров тестировщиках она 41,2% (107) и 37,5% (108). При этом у части
-- лидеров мало откликов (108 — 8, 106 — 10), так что их места неустойчивы.

-- ЗАДАНИЕ 5

WITH valid_messages AS (
  SELECT r.response_id,
         m.employer_id,
         m.message_id,
         m.sent_at,
         m.sender_role
    FROM messages m
    JOIN responses r ON r.response_id = m.response_id
   WHERE m.sent_at < r.created_at + INTERVAL '7 days'
),

messages_with_prev AS (
  SELECT response_id,
         employer_id,
         message_id,
         sent_at,
         sender_role,
         LAG(sender_role) OVER w AS prev_sender_role,
         LAG(sent_at) OVER w AS prev_sent_at
    FROM valid_messages
  WINDOW w AS (
    PARTITION BY response_id
    ORDER BY sent_at, message_id
   )
),

employer_replies AS (
  SELECT employer_id,
         message_id,
		 DATE_PART('epoch', sent_at - prev_sent_at) / 3600 AS reply_hours
    FROM messages_with_prev
   WHERE sender_role = 'employer'
     AND prev_sender_role = 'applicant'
)

-- общее кол-во таких ответов
-- SELECT COUNT(message_id)
--   FROM employer_replies;

SELECT employer_id,
       COUNT(*) AS reply_cnt,
       ROUND(AVG(reply_hours)::NUMERIC, 2) AS avg_hours,
       ROUND((PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY reply_hours))::NUMERIC, 2) AS median_hours,
       ROUND((PERCENTILE_CONT(0.9) WITHIN GROUP (ORDER BY reply_hours))::NUMERIC, 2) AS p90_hours
  FROM employer_replies
 GROUP BY employer_id
 ORDER BY median_hours, employer_id;


-- Комментарий:
-- общее количество найденных ответов: 749
-- employer_id работодателя с минимальной медианой: 107
-- значение его медианы: 3,93

-- Вывод:
-- У части работодателей ответов мало (105 - 6, 108 - 8), поэтому
-- их метрики неустойчивы, и поэтому выводы осторожные.
-- По медиане работодатели почти не различаются: все лежат в диапазоне 3,9–4,9 ч.
-- По p90 тоже близки (у всех 13–20 ч, то есть каждый десятый кандидат ждёт почти сутки).
-- Величина разрыва между средним и медианой и p90 вместе показывают, насколько
-- стабильно по времени работодатель отвечает. От работодателя, у которого оба показателя малы,
-- время ожидания ответа предсказуемее. Можно сказать, что по показателям 109 стабильнее всего
-- (у 105 очень мало сообщений), самый непредсказуемым выглядит 107. При этом стабильность и скорость —
-- разные вещи: 107 нестабильный, но его медианный ответ самый быстрый (3,93 ч),
-- а 109 ровный, но по медиане (4,42 ч) не лучший. То есть 109 отвечает предсказуемо,
-- а 107 либо очень быстро, либо с большой задержкой.

-- ============================================================
-- БЛОК Г. Сложные типы данных
-- ============================================================

-- ЗАДАНИЕ 6.1

WITH valid_calls AS (
  SELECT c.call_id,
         c.status,
         c.call_tags
    FROM calls c
    JOIN responses r ON r.response_id = c.response_id
   WHERE c.caller_role  = 'employer'
     AND c.call_at < r.created_at + INTERVAL '7 days'
),

-- нужный технический тег один, остальных нет
checked_calls AS (
  SELECT call_id,
         call_tags,
         CASE status
           WHEN 'successful' THEN 'connected'= ANY(call_tags)
                             AND NOT call_tags && ARRAY['no_answer', 'technical_error'] 
           WHEN 'unsuccessful' THEN 'no_answer' = ANY(call_tags)
                               AND NOT call_tags && ARRAY['connected', 'technical_error']
           WHEN 'error' THEN 'technical_error' = ANY(call_tags)
                        AND NOT call_tags && ARRAY['connected', 'no_answer']
           ELSE FALSE
         END AS is_consistent
    FROM valid_calls
)

SELECT COUNT(*) FILTER (WHERE is_consistent AND 'screening' = ANY(call_tags)) AS screening_cnt,
       COUNT(*) FILTER (WHERE is_consistent AND 'interview' = ANY(call_tags)) AS interview_cnt,
       COUNT(*) FILTER (WHERE is_consistent AND 'follow_up' = ANY(call_tags)) AS follow_up_cnt,
       COUNT(*) FILTER (WHERE is_consistent AND 'details' = ANY(call_tags)) AS details_cnt,
       COUNT(*) FILTER (WHERE is_consistent
                          AND call_tags && ARRAY['screening', 'interview', 'follow_up', 'details'])
                                                                              AS with_business_tag_cnt,
       ROUND(AVG(CARDINALITY(call_tags)) FILTER (WHERE is_consistent), 2) AS avg_tags_per_call
  FROM checked_calls;

-- Комментарий: 
-- тег screening: 25
-- тег interview: 31
-- тег follow_up: 29
-- тег details: 23
-- количество валидных звонков, содержащих хотя бы один из перечисленных бизнес-тегов: 108
-- среднее количество тегов на один валидный звонок: 4

-- Вывод: все 108 звонков работодателя за первые 7 дней прошли проверку согласованности
-- статуса и технических тегов, исключать ничего не пришлось. У каждого звонка ровно
-- один бизнес-тег (в сумме 108). Они распределены почти в равных долях.
-- То есть звонок используют на всех этапах отбора, а не только для первичного скрининга. Для интервью
-- звонок импользуют несколько больше, реже для согласования деталей.

-- ЗАДАНИЕ 6.2

WITH valid_messages AS (
  SELECT m.message_id,
         m.message_meta ->> 'channel' AS channel,
         (m.message_meta ->> 'is_read')::BOOLEAN AS is_read,
         CASE WHEN JSONB_TYPEOF(m.message_meta -> 'attachments') = 'array'
              THEN JSONB_ARRAY_LENGTH(m.message_meta -> 'attachments')
         END AS attachments_cnt
    FROM messages m
    	 JOIN responses r 
		 ON r.response_id = m.response_id
   WHERE m.sender_role = 'employer'
     AND m.sent_at < r.created_at + INTERVAL '7 days'
)

SELECT COALESCE(channel, 'channel_missing') AS channel,
       COUNT(*) AS msg_cnt,
       COUNT(is_read) AS read_known_cnt,
       COUNT(*) FILTER (WHERE NOT is_read) AS unread_cnt,
       ROUND(100.0 * COUNT(*) FILTER (WHERE NOT is_read)
                   / NULLIF(COUNT(is_read), 0), 2) AS unread_pct,
       COUNT(*) FILTER (WHERE attachments_cnt > 0) AS with_attachment_cnt,
       ROUND(100.0 * COUNT(*) FILTER (WHERE attachments_cnt > 0) / COUNT(*), 2) AS with_attachment_pct
  FROM valid_messages
 GROUP BY COALESCE(channel, 'channel_missing')
 ORDER BY msg_cnt DESC, channel;

-- Комментарий:
													 -- web		mobile_app
-- количество сообщений									628		360
-- ..., где признак прочтения присутствует				628		360
-- количество непрочитанных сообщений					52		36
-- долю непрочитанных, где признак прочтения известен	8,28	10
-- количество сообщений хотя бы с одним вложением		25		14
-- долю сообщений с вложением							3,98	3,89

-- Вывод: работодатели пишут в основном через веб (около 64% сообщений),
-- сообщений без канала нет. В мобильном приложении доля непрочитанных выше — 10,0%
-- против 8,28% в вебе, но разница не сильно большая, поэтому рано сравнивать каналы по этому признаку.
-- Вложения редки и от канала не зависят (около 4% в обоих), коммуникация почти полностью текстовая.

-- ============================================================
-- БЛОК Д. Самостоятельное исследование
-- ============================================================

-- ЗАДАНИЕ 7
-- Команда продукта хочет понять, отличаются ли коммуникации по откликам, которые заканчиваются
-- приглашением, от коммуникаций по остальным откликам — и если отличаются, то чем именно.

-- Гипотеза 1 ( ˘▽˘)っ: приглашение чаще там, где коммуникацию начал работодатель
-- окно - 7 дней с отклика 
-- используем слой событий работодателя (задание 2) и витрину отклика response_mart (задание 3)
WITH valid_calls AS (
  SELECT c.response_id,
         c.employer_id,
         c.call_id AS event_id,
         c.call_at AS event_at,
         'call' AS event_type,
		 c.caller_role AS initiator
    FROM calls c
         JOIN responses r
         ON r.response_id = c.response_id
   WHERE c.caller_role = 'employer'
     AND c.call_at < r.created_at + INTERVAL '7 days'
),

valid_messages AS (
  SELECT m.response_id,
         m.employer_id,
         m.message_id AS event_id,
         m.sent_at AS event_at,
         'message' AS event_type,
		 m.sender_role AS initiator
    FROM messages m
         JOIN responses r
         ON r.response_id = m.response_id
   WHERE m.sender_role = 'employer'
     AND m.sent_at < r.created_at + INTERVAL '7 days'
),

employer_events AS (
  SELECT * FROM valid_calls
  UNION ALL
  SELECT * FROM valid_messages
),

timeline AS (
  SELECT response_id,
         employer_id,
         event_id,
         event_at,
         event_type,
         ROW_NUMBER() OVER w AS event_num,
         LAG(event_at) OVER w AS prev_event_at,
         LAST_VALUE(event_type) OVER (w ROWS BETWEEN UNBOUNDED PRECEDING
                                                 AND UNBOUNDED FOLLOWING) AS last_event_type
    FROM employer_events
  WINDOW w AS (
    PARTITION BY response_id
    ORDER BY event_at, event_type, event_id
  )
),

gaps AS (
  SELECT response_id,
         event_id,
         ROUND((DATE_PART('epoch', event_at - prev_event_at) / 3600)::NUMERIC, 2) AS time_from_previous
    FROM timeline
),

response_mart AS (
  SELECT r.response_id,
         v.employer_id,
         v.professional_role,
         r.status AS response_status,
         COUNT(t.event_id) AS comm_cnt,
         COUNT(t.event_id) FILTER (WHERE t.event_type = 'call') AS call_cnt,
         COUNT(t.event_id) FILTER (WHERE t.event_type = 'message') AS msg_cnt,
         MIN(t.event_at) AS first_comm_at,
         MIN(t.event_type) FILTER (WHERE t.event_num = 1) AS first_comm_type,
         ROUND((DATE_PART('epoch', MIN(t.event_at) - r.created_at) / 3600)::NUMERIC, 2) AS hours_to_first_comm,
         MAX(g.time_from_previous) AS max_gap_hours
    FROM responses r
         JOIN vacancies v
         ON v.vacancy_id = r.vacancy_id
         LEFT JOIN timeline t
         ON t.response_id = r.response_id
         LEFT JOIN gaps g
         ON g.response_id = t.response_id
         AND g.event_id = t.event_id
   GROUP BY r.response_id, v.employer_id, v.professional_role, r.status, r.created_at
),

applicant_events AS (
  SELECT c.response_id,
         c.call_id AS event_id,
         c.call_at AS event_at,
         'call' AS event_type,
		 c.caller_role AS initiator
    FROM calls c
         JOIN responses r
         ON r.response_id = c.response_id
   WHERE c.caller_role = 'applicant'
     AND c.call_at < r.created_at + INTERVAL '7 days'
  UNION ALL
  SELECT m.response_id,
         m.message_id,
         m.sent_at,
         'message',
		 m.sender_role
    FROM messages m
         JOIN responses r
         ON r.response_id = m.response_id
   WHERE m.sender_role = 'applicant'
     AND m.sent_at < r.created_at + INTERVAL '7 days'
),


all_events AS (
  SELECT response_id, event_id, event_at, event_type, initiator
    FROM employer_events
  UNION ALL
  SELECT response_id, event_id, event_at, event_type, initiator
    FROM applicant_events
),

-- к отклику добавим, кто начал разговор и каким каналом
first_event AS (
  SELECT response_id,
         initiator,
         event_type AS channel
    FROM (
      SELECT response_id,
             initiator,
             event_type,
             ROW_NUMBER() OVER (PARTITION BY response_id
                                ORDER BY event_at, event_type, event_id) AS row_num
        FROM all_events
    ) ae
   WHERE row_num = 1
),

mart_with_initiator AS (
  SELECT rm.*,
         fe.initiator,
         fe.channel
    FROM response_mart rm
         LEFT JOIN first_event fe
         ON fe.response_id = rm.response_id
)

SELECT COALESCE(initiator, 'без коммуникаций') AS group_name,
       COUNT(*) AS response_cnt,
       ROUND(100.0 * COUNT(*) FILTER (WHERE response_status = 'invited') / COUNT(*), 1) AS conversion_pct,
       ROUND((PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY hours_to_first_comm))::NUMERIC, 2) AS median_hours_to_first_comm,
       ROUND(AVG(comm_cnt), 2) AS avg_comm_cnt,
       ROUND(100.0 * COUNT(*) FILTER (WHERE call_cnt > 0) / COUNT(*), 1) AS with_call_pct,
       ROUND((PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY max_gap_hours))::NUMERIC, 2) AS median_max_gap_hours
  FROM mart_with_initiator
 GROUP BY COALESCE(initiator, 'без коммуникаций')
 ORDER BY group_name DESC;

SELECT initiator,
       channel,
       COUNT(*) AS response_cnt,
       ROUND(100.0 * COUNT(*) FILTER (WHERE response_status = 'invited') / COUNT(*), 1) AS conversion_pct,
       ROUND((PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY hours_to_first_comm))::NUMERIC, 2) AS median_hours_to_first_comm,
       ROUND(AVG(comm_cnt), 2) AS avg_comm_cnt,
       ROUND(100.0 * COUNT(*) FILTER (WHERE call_cnt > 0) / COUNT(*), 1) AS with_call_pct,
       ROUND((PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY max_gap_hours))::NUMERIC, 2) AS median_max_gap_hours
  FROM mart_with_initiator
 WHERE channel IS NOT NULL
 GROUP BY initiator, channel
 ORDER BY initiator DESC, channel;


-- Комментарий:

-- Отклики делим по тому, кто начал разговор. Также выведем конверсию для откликов без коммуникации. Для контроля
-- те же группы делим по каналу первого контакта.
--
-- Метрики описывают, чем ещё различается коммуникация работодателя в группах,
-- и помогают понять, не объясняется ли разница в конверсии чем-то другим:
-- median_hours_to_first_comm — скорость: медиана часов от отклика до первого события
-- работодателя;
-- avg_comm_cnt — среднее число звонков и сообщений работодателя на отклик;
-- with_call_pct — доля откликов, где работодатель хотя бы раз позвонил;
-- median_max_gap_hours — медиана самой длинной паузы между коммуникациями работодателя.

-- Гипотеза подтверждается, если:
-- 1) конверсия в группе "начал работодатель" выше, чем в группе "начал кандидат";
-- 2) разница сохраняется в обоих каналах первого контакта (то есть не объясняется каналом);
-- 3) в каждой сравниваемой группе не меньше 30 откликов.

-- группа              откликов  invited  до 1-го контакта  ср. число   со звонком  макс. пауза
--                                        раб-ля (медиана)  коммуник.               (медиана)
-- 		 работодатель  272       15,1%    54,33 ч           2,84        33,8%       24,08 ч
-- 		 кандидат      126       11,9%    54,25 ч           2,57        8,7%        24,83 ч
-- без коммуникаций    230       15,7%    —                 0           0%          —

-- инициатор           канал       откликов  invited  до 1-го контакта  ср. число   со звонком  макс. пауза
-- 		 работодатель  звонком     66        15,2%    40,50 ч           2,26        100%        55,17 ч
-- 		 работодатель  сообщением  206       15,0%    55,75 ч           3,02        12,6%       23,43 ч
-- 		 кандидат      звонком     29        17,2%    122,00 ч          1,10        6,9%        24,10 ч
-- 		 кандидат      сообщением  97        10,3%    53,37 ч           3,01        9,3%        25,12 ч

-- Вывод: данных недостаточно. Основное сравнение совпадает с гипотезой: если первым на связь вышел работодатель,
-- приглашение получают 15,1% откликов (41 из 272), если кандидат — 11,9% (15 из 126).
-- Но разница сохраняется только при старте сообщением (15,0% против 10,3%), а при старте
-- звонком она меняет знак (15,2% против 17,2%), причём группа "начал кандидат - звонком"
-- слишком мала (29 откликов, меньше 30), поэтому условия 2 и 3 не выполняются. По скорости
-- группы не различаются (до первого контакта около 54 ч, максимальная пауза 24–25 ч),
-- объём близок (2,84 и 2,57 коммуникации), заметно отличается только канал: работодатель,
-- начавший разговор сам, звонит почти в 4 раза чаще (33,8% против 8,7%). 

-- Гипотеза 2 ( ˘▽˘)っ: к приглашению, чаще ведет коммуникация с работодателями из регионов, а не из Москвы



---------------------------------------- КОММЕНТАРИЙ-----------------------------------------------
-----------------------------           (про гипотезу)      ---------------------------------------

-- Гипотеза больше проверяет связь "регион - приглашение", нежели сравнивает разные коммуникации.
-- Поэтому гипотеза формально не отвечает на вопрос задания. Исследовать разницу коммуникаций можно, если изначально
-- знать, что конверсия в приглашения различатеся по регионам, и предположить, что дело в том, как ведут
-- коммуникацию эти разные группы. Тогда можно было бы переформулировать гипотезу как-то так:
-- коммуникация с работодателями из регионов чаще заканчивается приглашением, чем с московскими, 
-- и эта разница связана с тем, как они общаются: быстрее выходят на первый контакт, пишут больше и чаще звонят.
-- Регион здесь только способ разделить отклики на группы, а проверяем мы, отличается ли
-- в этих группах сама коммуникация.

---------------------------------------------------------------------------------------------------

-- окно - 7 дней с отклика

WITH valid_calls AS (
  SELECT c.response_id,
         c.employer_id,
         c.call_id AS event_id,
         c.call_at AS event_at,
         'call' AS event_type
    FROM calls c
         JOIN responses r
         ON r.response_id = c.response_id
   WHERE c.caller_role = 'employer'
     AND c.call_at < r.created_at + INTERVAL '7 days'
),

valid_messages AS (
  SELECT m.response_id,
         m.employer_id,
         m.message_id AS event_id,
         m.sent_at AS event_at,
         'message' AS event_type
    FROM messages m
         JOIN responses r
         ON r.response_id = m.response_id
   WHERE m.sender_role = 'employer'
     AND m.sent_at < r.created_at + INTERVAL '7 days'
),

employer_events AS (
  SELECT * FROM valid_calls
  UNION ALL
  SELECT * FROM valid_messages
),

timeline AS (
  SELECT response_id,
         employer_id,
         event_id,
         event_at,
         event_type,
         ROW_NUMBER() OVER w AS event_num,
         LAG(event_at) OVER w AS prev_event_at
    FROM employer_events
  WINDOW w AS (
    PARTITION BY response_id
    ORDER BY event_at, event_type, event_id
  )
),

gaps AS (
  SELECT response_id,
         event_id,
         ROUND((DATE_PART('epoch', event_at - prev_event_at) / 3600)::NUMERIC, 2) AS time_from_previous
    FROM timeline
),

response_mart AS (
  SELECT r.response_id,
         v.employer_id,
         v.professional_role,
         r.status AS response_status,
         r.created_at,
         COUNT(t.event_id) AS comm_cnt,
         COUNT(t.event_id) FILTER (WHERE t.event_type = 'call') AS call_cnt,
         COUNT(t.event_id) FILTER (WHERE t.event_type = 'message') AS msg_cnt,
         MIN(t.event_at) AS first_comm_at,
         ROUND((DATE_PART('epoch', MIN(t.event_at) - r.created_at) / 3600)::NUMERIC, 2) AS hours_to_first_comm,
         MAX(g.time_from_previous) AS max_gap_hours
    FROM responses r
         JOIN vacancies v
         ON v.vacancy_id = r.vacancy_id
         LEFT JOIN timeline t
         ON t.response_id = r.response_id
         LEFT JOIN gaps g
         ON g.response_id = t.response_id
         AND g.event_id = t.event_id
   GROUP BY r.response_id, v.employer_id, v.professional_role, r.status, r.created_at
),

response_level AS (
  SELECT rm.*,
         e.employer_name,
         a.area_name,
         CASE WHEN a.area_name = 'Москва' THEN 'Москва' ELSE 'регионы' END AS geo_label
    FROM response_mart rm
         JOIN employers e
         ON e.employer_id = rm.employer_id
         JOIN areas a
         ON a.area_id = e.area_id
   WHERE rm.comm_cnt > 0 --только отклики с коммуникацией
)

-- SELECT geo_label AS group_name,
--        COUNT(*) AS resp_cnt,
--        COUNT(DISTINCT employer_id) AS employer_cnt,
--        ROUND(100.0 * COUNT(*) FILTER (WHERE response_status = 'invited') / COUNT(*), 1) AS conversion_pct,
--        ROUND((PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY hours_to_first_comm))::NUMERIC, 2) AS median_hours_to_first_comm,
--        ROUND(AVG(comm_cnt), 2) AS avg_comm_cnt,
--        ROUND(100.0 * COUNT(*) FILTER (WHERE call_cnt > 0) / COUNT(*), 1) AS with_call_pct
--   FROM response_level
--  GROUP BY geo_label
--  ORDER BY (geo_label <> 'Москва');

-- SELECT geo_label,
--        area_name AS city,
--        COUNT(*) AS resp_cnt,
-- 	   COUNT(DISTINCT employer_id) AS employer_cnt,
--        ROUND(100.0 * COUNT(*) FILTER (WHERE response_status = 'invited') / COUNT(*), 1) AS conversion_pct,
--        ROUND((PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY hours_to_first_comm))::NUMERIC, 2) AS median_hours_to_first_comm,
--        ROUND(AVG(comm_cnt), 2) AS avg_comm_cnt,
--        ROUND(100.0 * COUNT(*) FILTER (WHERE call_cnt > 0) / COUNT(*), 1) AS with_call_pct
--   FROM response_level
--  GROUP BY geo_label, area_name
--  ORDER BY (geo_label <> 'Москва'), area_name;

 -- чтобы посмотреть, держится ли конверсия города на одной компании
SELECT area_name AS city,
       employer_id,
       employer_name,
       COUNT(*) AS resp_cnt,
       COUNT(*) FILTER (WHERE response_status = 'invited') AS invited_cnt,
       ROUND(100.0 * COUNT(*) FILTER (WHERE response_status = 'invited') / COUNT(*), 1) AS conversion_pct,
       ROUND((PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY hours_to_first_comm))::NUMERIC, 2) AS median_hours_to_first_comm,
       ROUND(AVG(comm_cnt), 2) AS avg_comm_cnt,
       ROUND(100.0 * COUNT(*) FILTER (WHERE call_cnt > 0) / COUNT(*), 1) AS with_call_pct
  FROM response_level
 GROUP BY area_name, employer_id, employer_name
 ORDER BY (area_name <> 'Москва'), area_name, conversion_pct DESC;


-- Комментарий:
-- Отклики делим по городу работодателя: "Москва" и "регионы" целиком
-- (основные группы), а регионы — ещё и по городам. Гипотеза говорит
-- именно о коммуникации, поэтому главный показатель считаем только по откликам, где
-- коммуникация была.

-- Метрики (считаются только по откликам с коммуникацией):
-- resp_cnt — число откликов в группе, показывает, насколько надёжны остальные цифры.
-- conversion_pct — доля откликов, закончившихся приглашением.
-- median_hours_to_first_comm — медиана часов от отклика до первого контакта.
-- avg_comm_cnt — среднее число звонков и сообщений работодателя на отклик.
-- with_call_pct — доля откликов, где работодатель хотя бы раз позвонил.


-- Гипотеза подтверждается, если:
-- 1) конверсия в регионах выше, чем в Москве;
-- 2) разница не держится на одном городе: каждый город, где не меньше 30 откликов
-- с коммуникацией, показывает конверсию выше московской;

---(тут скорее надо проверить другой критерий: коммуникация в регионах отличается от 
-- московской хотя бы по одной характеристике (скорость, объём, звонки), и это отличие 
-- повторяется в каждом городе, где конверсия выше московской)

-- допом проверить, не объясняется ли эффект отдельным работодателем в каждой группе

-- 3) в каждой сравниваемой группе не меньше 30 откликов с коммуникацией.

--       	 	   откликов  работ-ей	invited  до 1-го контакта  ср. число коммуник.  со звонком
-- Москва    		245      	4		11,8%    56,17 ч           2,9                 26,9%
-- регионы   		137      	7		18,2%    44,5 ч            2,81                 27%

-- Москва           245      	4		 11,8%    56,17 ч           2,90                 26,9%
-- Санкт-Петербург  46        	2		17,4%    52,67 ч           2,87                 32,6%
-- Екатеринбург     37        	2		18,9%    33,50 ч           2,86                 18,9%
-- Казань           32        	1		15,6%    31,26 ч           2,66                 25,0%
-- Новосибирск      22        	2		22,7%    55,17 ч           2,82                 31,8%

-- 		            работодатель      id   откликов  invited    конв.	до 1-го 		  ср. число  со звонком
--                                                                        контакта        коммуник.
-- Москва           Мосмаркет         102  61        10 		16,4%   76,83 ч            2,64       23,0%
-- Москва           Стартап Ноль      112  20        3 			15,0%    52,59 ч           3,20       30,0%
-- Москва           DataWave          103  89        9 			10,1%    54,33 ч           2,90       29,2%
-- Москва           ТехноБанк         101  75        7 			9,3%     54,67 ч           3,04       26,7%
-- Екатеринбург     Логистик Плюс     107  15        5 			33,3%    34,50 ч           3,00       26,7%
-- Екатеринбург     УралСофт          106  22        2 			9,1%     31,59 ч           2,77       13,6%
-- Казань           Казань Диджитал   110  32        5 			15,6%    31,26 ч           2,66       25,0%
-- Новосибирск      СибирьТелеком     108  5         2 			40,0%    5,67 ч            2,40       40,0%
-- Новосибирск      Академия Данных   109  17        3 			17,6%    56,97 ч           2,94       29,4%
-- Санкт-Петербург  Питер Ритейл      105  4         1 			25,0%    55,83 ч           2,75       50,0%
-- Санкт-Петербург  Северный Код      104  42        7 			16,7%    43,17 ч           2,88       31,0%

-- Вывод: не подтверждается. Первая часть гипотезы верна: среди откликов с коммуникацией
-- региональные работодатели приглашают чаще (18,2% против 11,8%), но похоже, что 
-- особенностями коммуникации эта разница не объясняется.
-- По объёму и каналу группы не различаются (2,81 и 2,90 коммуникации на отклик, 
-- звонок в 27,0% и 26,9% откликов). По скорости регионы в среднем быстрее (медиана
-- до первого контакта 44,5 ч против 56,2 ч), но это держится на Екатеринбурге и Казани
-- (33,5 и 31,3 ч), а в Санкт-Петербурге и Новосибирске время почти московское (52,7 и 55,2 ч)
-- при более высокой конверсии, поэтому условие 2 не выполняется. 
-- Разбивка по работодателям показывает, что разница между регионами и Москвой во многом определяется 
-- отдельными компаниями: в Екатеринбурге 18,9% дают Логистик Плюс (33,3%) и УралСофт (9,1%, ниже московского уровня), 
-- в Новосибирске СибирьТелеком (40,0%) имеет всего 5 откликов, а в Москве конверсия у Мосмаркета (16,4%) и 
-- Стартапа Ноль (15,0%) такая же, как у большинства региональных работодателей, и только DataWave и ТехноБанк
-- (10,1% и 9,3%) тянут московское среднее вниз. Без Логистик Плюс регионы остаются выше
-- Москвы (16,4% против 11,8%), но разброс внутри города не меньше, чем между городами,
-- поэтому разница может быть связана скорее с тем, какие это работодатели, чем с тем, как они общаются.
	

-- ЗАДАНИЕ 8. Итог исследования


-- сколько работодателей в каждом городе
SELECT a.area_name,
       COUNT(*) AS employer_cnt
  FROM employers e
       JOIN areas a
       ON a.area_id = e.area_id
 GROUP BY a.area_name
 ORDER BY employer_cnt DESC, a.area_name;
 

-- После получения отклика работодатели выходят на связь далеко не всегда: в первые 7 дней
-- коммуникация была только по 382 откликам из 628 (около 61%), а 246 откликов (около 39%)
-- остались без реакции. Если же работодатель отвечает, то почти всегда письменно: из 1096
-- событий 988 (около 90%) составляют сообщения, и в 82% откликов с коммуникацией первым
-- контактом тоже было сообщение. Звонок служит дополнительным инструментом, но используется
-- на всех этапах отбора примерно одинаково. В переписке работодатели отвечают похоже друг на друга:
-- медиана скорости ответа у всех лежит в диапазоне 3,9–4,9 ч, но p90 доходит до 13–20 ч, то есть
-- каждый десятый кандидат ждёт ответа почти сутки. Гораздо сильнее работодатели различаются
-- долей обработанных откликов, при этом активная обработка сама по себе не гарантирует приглашений: 
-- например, у работодателя DataWave (103) в аналитике данных обработано 84,8% откликов, но конверсия лишь 10,1%.
-- При проверке гипотез инициатива работодателя оказалась связана с приглашением лишь слабо и данных
-- оказалось недостаточно, чтобы сказать наверняка. Среди откликов с коммуникацией 
-- региональные работодатели приглашают чаще московских (18,2% против 11,8%). Однако это просто 
-- наблюдаемая связь, а не причина. Регион, направление и конкретный работодатель переплетены, 
-- а качество резюме кандидата мы не видим. Еще одно ограничение анализа в том, что работодателей
-- всего 12 (по 2 в каждом регионе), поэтому эффекты города и места в рейтинге нельзя отделить 
-- от особенностей конкретных компаний. Следующим исследовательским вопросом я бы сделала такой: 
-- как кандидат получает приглашение, если по отклику нет данных о коммуникациях? По 230 откликам 
-- в первую неделю нет ни одного звонка или сообщения ни от одной из сторон, 
-- но 15,7% всё равно заканчиваются приглашением. Чтобы понять, откуда берутся такие приглашения, 
-- я бы запросила дату приглашения, время просмотра отклика работодателем и данные о связи вне сервиса 
-- (почта, мессенджеры) и посчитала, какая доля из них объясняется поздней коммуникацией после 7-го дня,
-- какая — контактом вне сервиса, а какая — приглашением сразу по резюме.
