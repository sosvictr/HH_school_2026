-- ============================================================
-- Домашнее задание к лекции «SQL. Введение»
-- Школа Аналитиков · учебная база hh_school
-- Автор: Иванова Виктория Владимировна
-- ============================================================

SET search_path TO hh_school;

-- ============================================================
-- БЛОК А. Разминка: термины и структура (текстом)
-- ============================================================

-- ЗАДАНИЕ А1
-- 1. Категория и конкретный тип колонок:
--    vacancies.salary_from        — категория: числовые   тип: INTEGER
--    vacancies.vacancy_name       — категория: строковые   тип: TEXT
--    vacancies.published_at       — категория: дата и время   тип: TIMESTAMP
--    employers.is_accredited_it   — категория: логические   тип: BOOLEAN
--    responses.created_at         — категория: дата и время   тип: TIMESTAMP
--
-- 2. Первичные ключи таблиц:
--    areas: area_id
--    employers: employer_id
--    vacancies: vacancy_id
--    vacancy_details: vacancy_id (чем особенный: является также внешним ключом к таблице vacancies.)
--    responses: response_id

--
-- 3. Почему vacancy_name не может быть первичным ключом:
--    Значение vacancy_name не уникально для каждой строки таблицы vacancies,
--    поэтому не может быть использован для однозначной идентификации вакансии в таблице.

--    Запрос для подтверждения числом:
-- запрос, который покажет, сколько раз в базе встречается самое частое название вакансии.
SELECT vacancy_name,
	   count(vacancy_name) as vacancy_name_cnt
  FROM vacancies
 GROUP BY vacancy_name
 ORDER BY vacancy_name_cnt DESC
 LIMIT 1;


-- Самое частое название — «Стажёр: аналитик данных», оно встречается 6 раз

-- запрос:

SELECT count(*) AS total_rows, --52
	   count(DISTINCT vacancy_name) AS total_vacancies_names, --18
	   count(*) - count(DISTINCT vacancy_name) as rows_difference --34
  FROM vacancies;

-- Вывод:
-- Запрос показал, что в таблице 52 строки, но уникальных названий только 18, то есть 34 строки
-- повторяют уже существующее название. Значит, по vacancy_name нельзя однозначно найти вакансию,
-- а первичный ключ должен быть уникальным для каждой строки.


-- 4. Что произойдёт при записи строки «по договорённости» в salary_from:

--    INSERT INTO vacancies (salary_from) VALUES ('по договорённости');

--    Строка не будет записана вообще. Произойдёт ошибка, и таблица останется такой же, как до запроса.
--    При попытке передать строку в salary_from в тексте ошибки будет информация, что колонка salary_from
--    предназначена для int. Однако, даже передавая числовой тип, все равно бы произошла ошибка, поскольку
--    необходимо проинициализировать обязательные колонки vacancy_id (ПК таблицы) и published_at (NOT NULL и нет DEFAUL значения).
--    Получается, что сначала происходит проверка на тип, затем на обязательные колонки.
--    Строгая типизация защищает данные: в колонке с типом INTEGER могут лежать только числа, и СУБД не даёт записать туда
--    значение другого типа. Так предотвращаются операции с данными разных типов, например сложение числа с текстом.

-- ============================================================
-- БЛОК Б. Первые запросы: SELECT, WHERE, ORDER BY
-- ============================================================

-- ЗАДАНИЕ Б1
-- Запрос: experience
SELECT DISTINCT experience
  FROM vacancies
 ORDER BY experience;

-- Запрос: employment
SELECT DISTINCT employment
  FROM vacancies
 ORDER BY employment;

-- Запрос: professional_role
SELECT DISTINCT professional_role
  FROM vacancies
 ORDER BY professional_role;


-- Вывод:
-- В вакансиях:
-- всего 3 категории опыта: нет опыта, от 1 до 3 лет, от 3 до 6 лет.
-- всего 3 категории занятости: частичная занятость, стажировка, полная занятость.
-- всего 5 профессиональных направлений: дата-инженер, разработчик, продуктовый аналитик, аналитик данных, тестировщик.
-- Проблем с качеством не обнаружено: NULL нет ни в одной из трёх колонок (DISTINCT вывел бы NULL), 
-- и каждое значение записано единообразно (иначе DISTINCT показал бы их отдельными строками). 


-- ЗАДАНИЕ Б2
-- Запрос 1: стажировки в Москве без опыта, вакансия открыта
SELECT vacancy_id, vacancy_name, salary_from, published_at
  FROM vacancies
 WHERE employment = 'Стажировка'
   AND closed_at IS NULL
   AND experience = 'Нет опыта'
   AND area_id = (SELECT area_id
	  			    FROM areas
				   WHERE area_name = 'Москва')
 ORDER BY published_at DESC;

-- Проверка: то же самое, но без условия про Москву
-- SELECT count(*) AS open_internships_all_cities
-- FROM vacancies
-- WHERE employment = 'Стажировка'
--       AND closed_at IS NULL
--       AND experience = 'Нет опыта';

-- Запрос 2: топ-10 вакансий по salary_from
SELECT vacancy_name, professional_role, salary_from
  FROM vacancies
 ORDER BY salary_from DESC NULLS LAST
 LIMIT 10;

-- Вывод:
-- Требуемых открытых стажерских позиций без опыта и в Москве найдено 8 штук. Ограничение: у одной из 8 зарплата не указана.
-- Если убрать условие про Москву, число вырастет всего до 10: добавятся стажировки в других городах.
-- В топ-10 по salary_from нет ни одной стажировки (стажеру не повезло :<). Топ состоит из Senior-позиций и разработчиков.


-- ЗАДАНИЕ Б3
-- Ловушка 1. NULL — выполнить и объяснить результат
SELECT count(*) 
  FROM vacancies 
 WHERE closed_at = NULL;
 
SELECT count(*)
  FROM vacancies
 WHERE closed_at IS NULL;

-- Ловушка 2. AND / OR — выполнить и объяснить результат
SELECT count(*)
  FROM vacancies
 WHERE area_id = 1 
    OR area_id = 2 
   AND experience = 'Нет опыта';

SELECT count(*)
  FROM vacancies
 WHERE (area_id = 1 OR area_id = 2) 
   AND experience = 'Нет опыта';

-- Вывод:
-- 1) Запись closed_at = NULL синтаксически корректна. Однако сравнение с NULL с помощью оператора равенства (=) никогда не истинно.
-- Его результат не TRUE и не FALSE, а UNKNOWN, а WHERE пропускает только строки с TRUE, поэтому условие фильтрации не выполняется
-- ни для одной строки таблицы и поэтому в результате кол-во строк 0.
-- Почему это опаснее ошибки: формально запрос отработает, но его поведение будет не такое, как ожидается, из-за особенности работы с NULL.
-- Что такое NULL в closed_at: дата закрытия вакансии не наступила, значит она открыта
-- 2) У AND приоритет выше, чем у OR, поэтому первое условие читается как area_id = 1 OR (area_id = 2 AND experience = 'Нет опыта'):
-- все вакансии Москвы (любого опыта) плюс вакансии Санкт-Петербурга без опыта. Получилась 31 вкансия.
-- Во втором запросе скобки задают другую логику: (Москва ИЛИ Санкт-Петербург) И без опыта.
-- Получилось 20. Разница в 11 строк — это вакансии Москвы, где требуется опыт.
-- На вопрос «вакансии из Москвы или Санкт-Петербурга, но обязательно без опыта» отвечает второй запрос (20).

-- ============================================================
-- БЛОК В. Агрегации и метрики
-- ============================================================

-- ЗАДАНИЕ В1
-- Запрос 1: счётчики (строки, зарплата указана, направления, работодатели)

SELECT count(*) AS all_vacancies,
       count(salary_from) AS with_salary, -- считаю, что зарплата указана, если заполнено salary_from
       count(DISTINCT professional_role) AS roles,
       count(DISTINCT employer_id) AS employers
  FROM vacancies;


-- Запрос 2: доля активных вакансий (без JOIN)

SELECT count(*) - count(closed_at) AS open_vacancies,
       count(closed_at) AS closed_vacancies,
       round(100.0 * (1 - count(closed_at)::numeric / count(*)), 1) AS active_vacancies
  FROM vacancies;

-- Вывод:
-- 1) В таблице 52 вакансии от 12 работодателей по 5 направлениям. Зарплата указана в 44 вакансиях, то есть у 8 вакансий она пустая.
-- Активными остаются 63,5% вакансий, остальные закрыты.
-- Разница между функциями:
-- count(*) = 52 — столько всего строк в таблице vacancies;
-- count(salary_from) = 44 — столько строк в таблице, где в колонке salary_from есть значение. Остальные 8 имеют NULL, их функция пропускает;
-- count(DISTINCT professional_role) = 5 - у всех вакансий столько уникальных профессиональных направлений и count(DISTINCT employer_id) = 12 - столько работодателей,
-- 2) Ответ руководителю: «Сейчас активны 33 вакансии из 52 — это 63,5%, остальные 19 уже закрыты».


-- ЗАДАНИЕ В2
-- Запрос 1: направления — вакансии, работодатели, средняя зарплата
SELECT professional_role,
	   count(*) AS vacancies_count,
	   count(DISTINCT employer_id) AS employers_count,
	   round(avg(salary_from)) AS avg_salary_from
  FROM vacancies
 GROUP BY professional_role
 ORDER BY vacancies_count DESC;

-- Запрос 2: то же, только направления с ≥ 5 открытыми вакансиями (WHERE + HAVING)

SELECT professional_role,
	   count(*) AS vacancies_count,
	   count(DISTINCT employer_id) AS employers_count,
	   round(avg(salary_from)) AS avg_salary_from
  FROM vacancies
 WHERE closed_at IS NULL
 GROUP BY professional_role
 HAVING count(*) >= 5
 ORDER BY vacancies_count DESC;

-- Вывод:
-- 1) Больше всего вакансий у аналитика данных и разработчика — 31 вакансия из 52 (59,6%).
-- Соискатель по этой таблице решил бы: "иду в аналитику данных или разработку — там больше всего мест".
-- Но обоснованным такой вывод не является: в таблице нет конкуренции (сколько откликов приходится на вакансию)
-- и шансов (конверсии в приглашение).
--
-- 2) Почему "только открытые" — в WHERE, а "не менее пяти" — в HAVING: 
-- Это связано с порядком выполнения запросов. WHERE фильтрует отдельные строки ещё ДО группировки:
-- "открыта ли вакансия" — свойство одной строки. «"е менее пяти вакансий" — свойство группы, его можно
-- проверить только ПОСЛЕ GROUP BY, когда count(*) уже посчитан, поэтому это работа HAVING.
-- Если написать WHERE count(*) >= 5, будет ошибка, что агрегатные функции не разрешены в WHERE, запрос не выполнится
--
-- 3) avg(salary_from) отвечает на вопрос: "какова средняя нижняя граница зп среди вакансий направления, у которых она УКАЗАНА".
-- И не отвечает - "какова средняя нижняя граница зп среди ВСЕХ вакансий направления"

-- ============================================================
-- БЛОК Г. Соединение таблиц
-- ============================================================

-- ЗАДАНИЕ Г1
-- Запрос: топ-5 по salary_from с названием компании и городом (псевдонимы таблиц)
SELECT v.vacancy_name, e.employer_name, a.area_name, v.salary_from
  FROM vacancies v
	   INNER JOIN employers e 
	   ON v.employer_id = e.employer_id
	   
	   INNER JOIN areas a 
	   ON v.area_id = a.area_id
 ORDER BY v.salary_from DESC NULLS LAST
 LIMIT 5;

-- Вывод:
-- В топ-5 вакансий по salary_from вошли только позиции уровня Senior: разработчик, дата-инженер и три аналитика данных,
-- с зарплатой от 140 до 195 тысяч рублей. Вакансии распределены по четырём городам и четырём компаниям,
-- при этом две вакансии принадлежат Северному Коду (Санкт-Петербург), а Москва представлена только ТехноБанком на пятом месте.

-- Город берётся через v.area_id — это город вакансии, а не город головного офиса (e.area_id).
-- Что будет, если убрать псевдонимы и написать просто area_id, то запрос упадёт с ошибкой.
-- Колонка area_id есть сразу в трёх соединённых таблицах — vacancies, employers и areas, и СУБД не может угадать, из какой колонка.
-- Причём значения в них могут различаться, напрмиер, город вакансии и город работодателя. Псевдоним явно говорит, из какой таблицы брать колонку.


-- ЗАДАНИЕ Г2
-- Запрос 1: все работодатели, число вакансий и откликов (LEFT JOIN)
SELECT e.employer_name,
       count(DISTINCT v.vacancy_id) AS vacancies,
       count(r.response_id) AS responses
  FROM employers e
	   LEFT JOIN vacancies v 
	   ON e.employer_id = v.employer_id
	   LEFT JOIN responses r 
	   ON v.vacancy_id = r.vacancy_id
 GROUP BY e.employer_name
 ORDER BY responses DESC;

-- проверка для наглядности
-- SELECT e.employer_name,
--        v.vacancy_id AS vacancies,
--        r.response_id AS responses
--   FROM employers e
-- 	   LEFT JOIN vacancies v 
-- 	   ON e.employer_id = v.employer_id
-- 	   LEFT JOIN responses r 
-- 	   ON v.vacancy_id = r.vacancy_id
--  GROUP BY e.employer_name, v.vacancy_id, r.response_id
--  ORDER BY e.employer_name;


-- Запрос 2: тот же запрос с INNER JOIN
SELECT e.employer_name,
       count(DISTINCT v.vacancy_id) AS vacancies,
       count(r.response_id) AS responses
  FROM employers e
	   INNER JOIN vacancies v 
	   ON e.employer_id = v.employer_id
	   INNER JOIN responses r 
	   ON v.vacancy_id = r.vacancy_id
 GROUP BY e.employer_name
 ORDER BY responses DESC;


-- проверка для наглядности
-- SELECT e.employer_name,
--        v.vacancy_id AS vacancies,
--        r.response_id AS responses
--   FROM employers e
-- 	   INNER JOIN vacancies v 
-- 	   ON e.employer_id = v.employer_id
-- 	   INNER JOIN responses r 
-- 	   ON v.vacancy_id = r.vacancy_id
--  GROUP BY e.employer_name, v.vacancy_id, r.response_id
-- ORDER BY e.employer_name;

-- Вывод:
-- LEFT JOIN вернул 12 работодателей, INNER JOIN вернул 11 работодателей. Из результата INNER пропал ГринЭнерго:
-- его единственная вакансия не получила ни одного отклика.

-- что за вакансия у ГринЭнерго 
SELECT v.vacancy_name, v.professional_role, v.experience, a.area_name,
       v.salary_from, v.salary_to,
       v.published_at::date AS published, 
	   v.closed_at::date AS closed,
	   (v.closed_at::date - v.published_at::date) AS days_before_closing
  FROM vacancies v
	   JOIN employers e 
	   ON e.employer_id = v.employer_id
	   AND e.employer_name = 'ГринЭнерго'
	   JOIN areas a ON a.area_id = v.area_id

-- У компании одна вакансия «Стажёр: разработчик».
-- Она была открыта 28 дней (6 апреля – 4 мая).
-- Ноль откликов может получиться по разным причинам. Некоторые гипотезы разберу ниже.

-- сопоставимые вакансии — разработчики без опыта (считаю, что сопоставимые вакансии, условно те, 
-- которые привлекают одних и тех же кандидатов)

SELECT e.employer_name, 
	   v.vacancy_name, 
	   v.salary_from,
       v.published_at::date AS published,
	   v.closed_at::date AS closed,
	   (v.closed_at::date - v.published_at::date) AS days_before_closing,
       count(r.response_id) AS responses,
	   min(r.created_at)::date - v.published_at::date AS days_to_first_response
  FROM vacancies v
	   JOIN employers e 
	   ON e.employer_id = v.employer_id
	   LEFT JOIN responses r 
	   ON r.vacancy_id = v.vacancy_id
 WHERE v.professional_role = 'Разработчик' AND v.experience = 'Нет опыта'
 GROUP BY e.employer_name, v.vacancy_id, v.vacancy_name, v.salary_from, v.published_at, v.closed_at
 ORDER BY e.employer_name DESC,
 		  v.vacancy_name;

-- Какие объяснения нуля откликов у ГринЭнерго можно предположить:
-- 1) "Не успели откликнуться": вакансия висела 28 дней, а у других вакансий первый отклик приходил максимум через 15 дней 
-- (у УралСофт и Северный Код в первый же день).
-- 2) "Апрель — плохое время для размещения вакансии": апрельские вакансии разработчиков без опыта получили 0, 0 и 6 откликов, 
-- а опубликованные в другие месяцы — в среднем около 12. Разрыв заметный, но таких вакансий всего три, а данные только за один год,
-- поэтому отличить сезон от совпадения нельзя.
-- 3) "К таким вакансиям нет интереса": из 8 вакансий разработчиков без опыта 5 получили от 6 до 27 откликов.
-- 4) "Нет зарплаты" — проверить нельзя: вакансия без зарплаты одна, сравнивать не с чем. При этом есть вакансии без откликов с зарплатой
--
-- Вывод: у вакансии ГринЭнерго результат необычный: не объясняется точно ни сроком, ни тем, что такие вакансии не интересны. Возможно, что 
-- причина в самой вакансии (описание, требования, место размещения), но по этим данным это не доказать.
--
-- Вывод дл hr: у вакансий может быть разная причина, почему на них не откликаются, поэтому одно количество откликов
-- не даёт полезной метрики. Нужно изучать интенсивность откликов по каждой вакансии и как это зависит от особенностей вакансии и не только
-- (сезон, направление, опыт, зарплата, срок размещения). Например, у ГринЭнерго за 28 дней нет ни одного отклика,
-- хотя у похожих вакансий первый приходил максимум через 15 дней. Без такого разбора нельзя понять,
-- нет ли интереса к вакансии или дело в том, как она оформлена или других обстоятельстваз.

-- Почему исчезновение ГринЭнерго — содержательная потеря, а не техническая мелочь:
-- Отчёт для HR показывает, как работодатели получают отклики, и нужен, чтобы увидеть слабые места. Для дальнейшего анализа откликов 
-- это искажает результат: пропадают нулевые значения, и средние показатели, доля работодателей с откликами и охват выглядят лучше, 
-- чем есть на самом деле.
--
-- Правило выбора: перед JOIN задаю себе вопрос "должны ли в результате остаться строки левой таблицы, у которых
-- нет пары?". Если я строю отчёт по списку объектов и ноль — это тоже ответ, нужен LEFT JOIN.
-- INNER JOIN — только когда меня интересуют исключительно совпавшие пары и отсутствие пары означает, что строка мне не нужна.


-- ============================================================
-- БЛОК Д. Функции и финальный кейс
-- ============================================================

-- ЗАДАНИЕ Д1
-- Запрос: помесячная динамика откликов и конверсия
-- (месяц как дата, условный агрегат, nullif в знаменателе)

SELECT date_trunc('month', created_at)::date AS month,
       count(*) AS responses,
       count(*) FILTER (WHERE status = 'invited') AS invited,
       round(100.0 * count(*) FILTER (WHERE status = 'invited')
             / nullif(count(*), 0), 1) AS conversion_pct
  FROM responses
 GROUP BY 1
 ORDER BY 1;


-- Вывод:
-- 1) Наибольшая конверсия в приглашение — в июне (19,5%, 23 приглашений из 118 откликов).
-- Объём у июня большой. 118 откликов это второй результат после июля (142), и он примерно в 1,4 раза выше среднего 
-- по полным месяцам (январь–июль, около 84 откликов). Для сравнения, в январе откликов всего 24, и там одно приглашение 
-- сдвигает конверсию примерно на 4%. Так что процент в июне устойчивее.
-- С учётом этого июнь можно считать лучшим ориентиром по имеющимся данным, но уверенно утверждать,
-- что шанс приглашения именно в июне выше, нельзя.
-- 

-- 2)
-- Дополнительная проверка
-- SELECT date_trunc('month', created_at)::date AS month,
--        min(created_at)::date AS first_response,
--        max(created_at)::date AS last_response,
--        round(100.0 * count(*) FILTER (WHERE status IN ('new', 'viewed'))
--              / nullif(count(*), 0), 1) AS new_or_viewed_pct
-- FROM responses
-- GROUP BY 1
-- ORDER BY 1;
--
-- В августе наименьшая конверсия и довольно мало откликов. К тому же, данные обрываются 15 августа, то есть месяц неполный. 
-- и в месяце всего 41 отклик, когда в соседних по 100 и больше. Объёмы несопоставимы с другими месяцами.
-- Август лучше исключить из выводов.


-- ЗАДАНИЕ Д2
-- Запрос: таблица по направлениям (вакансии, отклики, приглашения,
-- откликов на вакансию, конверсия)

SELECT v.professional_role,
       count(DISTINCT v.vacancy_id) AS vacancies,
       count(r.response_id) AS responses,
       count(r.response_id) FILTER (WHERE r.status = 'invited') AS invited,
       round(1.0 * count(r.response_id)
             / nullif(count(DISTINCT v.vacancy_id), 0), 1) AS responses_per_vacancy,
       round(100.0 * count(r.response_id) FILTER (WHERE r.status = 'invited')
             / nullif(count(r.response_id), 0), 1) AS conversion_pct
  FROM vacancies v
	   LEFT JOIN responses r 
	   ON v.vacancy_id = r.vacancy_id
 GROUP BY v.professional_role
 ORDER BY conversion_pct DESC;


-- Письменные ответы:
-- 1. Направление с наибольшим числом вакансий с направлением
--    с наибольшей конверсией?
--    Нет, наибольшая конверсия у тестировщика, а наибольшее кол-во вакансий в аналитике данных.
-- 2. Какое направление выбрать и почему (опираясь на два столбца):
-- 	  Целесообразно выбрать направление тестировщика, так как конверсия отклика (conversion_pct) в приглашение здесь самая высокая (35,9%), а конкуренция
-- 	  (responses_per_vacancy) почти самая низкая (5,6) (ниже только дата-инженер — 4,9).
-- 3. Оговорка к выводу:
-- 	  Конверсия считается по всем откликам, включая необработанные (статусы new и viewed), поэтому она занижена у тех направлений, где решений ещё нет.
-- 	  Во-вторых, у тестировщиков и дата-инженеров откликов мало, а конверсия, посчитанная по небольшой группе, сильно зависит от каждого
-- 	  отдельного отклика, поэтому сравнивать её с другими направлениями нужно осторожно.


-- ============================================================
-- БЛОК Е. Со звёздочкой
-- ============================================================

-- ЗАДАНИЕ Е1
-- Исходный запрос (выполнить и посмотреть результат):
-- SELECT v.professional_role,
-- count(*) AS vacancies,
-- sum(v.salary_from) AS total_salary,
-- count(r.response_id) / count(*) AS responses_per_vacancy
-- FROM vacancies v
-- JOIN responses r ON v.vacancy_id = r.vacancy_id
-- WHERE v.closed_at = NULL
-- GROUP BY 1;
-- смотрим метрики по открытым вакансиям

-- Ошибки (минимум четыре):
-- 1. WHERE v.closed_at = NULL. Сравнение с NULL через = никогда не истинно, поэтому не проходит ни одна строка.
-- 2. (INNER) JOIN responses r ON v.vacancy_id = r.vacancy_id . Вакансии без откликов теряются.
-- 3. count(*) AS vacancies после INNER JOIN. Строка вакансии размножается по числу её откликов, поэтому count(*) считает отклики, а не вакансии.
-- 4. count(r.response_id) / count(*). После JOIN оба значения равны числу строк, и результат 1.
-- 5. count(r.response_id) / count(*). Не учтена арифметика с NULL, если нет откликов, то вернет NULL.
-- 6. sum(v.salary_from). Суммируются также все размноженные после JOIN вакансии по несколько раз.
-- 7. sum(v.salary_from). Неудачная метрика: сумма нижних границ зарплат по разным вакансиям не дает четкого представления об уровне оплаты 
-- в направлении. Для сравнения оплаты труда направлений нужна средняя зарплата на одну вакансию.

WITH responses_per_vacancy AS (
     SELECT vacancy_id,
           count(*) AS responses
       FROM responses
      GROUP BY vacancy_id
)

SELECT v.professional_role,
       count(*) AS vacancies,
       round(1.0 * avg(v.salary_from), 1) AS avg_salary, -- введем среднюю зарплату открытых вакансий среди тех, где она указана
       round(1.0 * sum(coalesce(r.responses, 0))
             / nullif(count(*), 0), 1) AS responses_per_vacancy
  FROM vacancies v
	   LEFT JOIN responses_per_vacancy r 
	   ON r.vacancy_id = v.vacancy_id
 WHERE v.closed_at IS NULL
 GROUP BY v.professional_role
 ORDER BY vacancies DESC;


-- Какие два правила из лекции защитили бы от этих ошибок при написании запроса:
-- 1. сравнение с NULL никогда не истинно — пустоту проверяют оператором IS NULL
-- 2. INNER JOIN оставляет только совпадения, LEFT JOIN сохраняет все строки левой таблицы
