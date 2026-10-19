-- ============================================================
-- Домашнее задание к лекции «SQL. Введение»
-- Школа Аналитиков · учебная база hh_school
-- Автор: Иванова Виктория Владимировна
-- ============================================================
-- Формат: задания по порядку, каждое начинается с комментария
-- с номером; под каждым запросом — вывод (2–3 предложения).
-- Запрос без вывода не засчитывается.
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
--    vacancy_details: vacancy_id (чем особенный: является также внешним ключом к таблице vacancies. Значит, связь м/у таблицами 1:1)
--    responses: response_id
--
-- 3. Почему vacancy_name не может быть первичным ключом:
--    Значение vacancy_name не уникально для каждой строки таблицы vacancies, 
--    поэтому не может быть использован для однозначной идентификации вакансии в таблице.

--    Запрос для подтверждения числом:

SELECT count(*) -
	   count(DISTINCT vacancy_name) as rows_difference
FROM vacancies; -- 34

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
-- всего 3 категории опыта: нет опыта, от 1 до 6 лет, от 3 до 6 лет.
-- всего 3 категории занятости: частичная занятость, стажировка, полная занятость.
-- всего 5 профессиональных направлений: дата-инженер, разработчик, продуктовый аналитик, аналитик данных, тестировщик.


-- ЗАДАНИЕ Б2
-- Запрос 1: стажировки в Москве без опыта, вакансия открыта
SELECT vacancy_name, salary_from
FROM vacancies
WHERE employment = 'Стажировка' 
	  AND closed_at IS NULL
      AND experience = 'Нет опыта'
	  AND area_id = (SELECT area_id 
	  				 FROM areas
					 WHERE area_name = 'Москва'
	  );
      
-- Запрос 2: топ-10 вакансий по salary_from
SELECT vacancy_name, salary_from, closed_at
FROM vacancies
ORDER BY salary_from DESC NULLS LAST
LIMIT 10;

-- Вывод:
-- Требуемых стажерских позиций найдено 8 штук. Из них 5 по напралвению аналитики данных.
-- В топ-10 по salary_from нет ни одной стажировки (стажеру не повезло :<). А 3 вакансии уже закрыты.


-- ЗАДАНИЕ Б3
-- Ловушка 1. NULL — выполнить и объяснить результат
SELECT count(*) FROM vacancies WHERE closed_at = NULL;
SELECT count(*) FROM vacancies WHERE closed_at IS NULL;

-- Ловушка 2. AND / OR — выполнить и объяснить результат
SELECT count(*) FROM vacancies
WHERE area_id = 1 OR area_id = 2 AND experience = 'Нет опыта';

SELECT count(*) FROM vacancies
WHERE (area_id = 1 OR area_id = 2) AND experience = 'Нет опыта';

-- Вывод:
-- 1) Сравнение с NULL с помощью оператора равенства (=) никогда не истинно, поэтому условие фильтрации не выполняется
-- ни для одной строки таблицы и поэтому в результате кол-во строк 0. Для проверки на NULL нужен оператор IS NULL. Используя его,
-- получим 33 строки.
-- 2) У AND приоритет выше, чем у OR, поэтому первое условие читается как area_id = 1 OR (area_id = 2 AND experience = 'Нет опыта'): 
-- все вакансии Москвы (любого опыта) плюс стажёрские вакансии Санкт-Петербурга. Получилось 31 строка.
-- Во втором запросе скобки задают другую логику: (Москва ИЛИ Санкт-Петербург) И без опыта.
-- Получилось 20 строк. Разница в 11 строк — это вакансии Москвы, где требуется опыт.

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

SELECT round(100.0 * (1 - count(closed_at)::numeric / count(*)), 1) AS active_vacancies
FROM vacancies;

-- Вывод:
-- В таблице 52 вакансии от 12 работодателей по 5 направлениям. Зарплата указана в 44 вакансиях, 
-- то есть у 8 вакансий она пустая. 
-- Активными остаются 63,5% вакансий, остальные закрыты.


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
GROUP BY professional_role
HAVING count(*) - count(closed_at) >= 5;

-- Вывод:
-- Всего представлено 5 направлений, больше всего вакансий у аналитиков данных (16) и разработчиков (15). 
-- С более 5 открытыми вакансиям (≥ 5) осталось 4 направления: продуктовый аналитик выбыл, 
-- так как из 7 его вакансий открыты только 4.


-- ============================================================
-- БЛОК Г. Соединение таблиц
-- ============================================================

-- ЗАДАНИЕ Г1
-- Запрос: топ-5 по salary_from с названием компании и городом (псевдонимы таблиц)
SELECT v.vacancy_name, v.salary_from, e.employer_name, a.area_name 
FROM vacancies v
INNER JOIN employers e ON v.employer_id = e.employer_id
INNER JOIN areas a ON v.area_id = a.area_id
ORDER BY v.salary_from DESC NULLS LAST
LIMIT 5;

-- Вывод:
-- В топ-5 вакансий по salary_from вошли только позиции уровня Senior: разработчик, дата-инженер и три аналитика данных,
-- с зарплатой от 140 до 195 тысяч рублей. Вакансии распределены по четырём городам и четырём компаниям,
-- при этом две вакансии принадлежат Северному Коду (Санкт-Петербург), а Москва представлена только ТехноБанком на пятом месте.
-- Самые высокие нижние границы вилки предлагают регионы, а не столица.


-- ЗАДАНИЕ Г2
-- Запрос 1: все работодатели, число вакансий и откликов (LEFT JOIN)
SELECT e.employer_name,
       count(DISTINCT v.vacancy_id) AS vacancies,
       count(r.response_id) AS responses
FROM employers e
LEFT JOIN vacancies v ON e.employer_id = v.employer_id
LEFT JOIN responses r ON v.vacancy_id = r.vacancy_id
GROUP BY e.employer_name
ORDER BY e.employer_name;

-- проверка для наглядности
-- SELECT e.employer_name,
--        v.vacancy_id AS vacancies,
--        r.response_id AS responses
-- FROM employers e
-- LEFT JOIN vacancies v ON e.employer_id = v.employer_id
-- LEFT JOIN responses r ON v.vacancy_id = r.vacancy_id
-- GROUP BY e.employer_name, v.vacancy_id, r.response_id
-- ORDER BY e.employer_name;


-- Запрос 2: тот же запрос с INNER JOIN
SELECT e.employer_name,
       count(DISTINCT v.vacancy_id) AS vacancies,
       count(r.response_id) AS responses
FROM employers e
INNER JOIN vacancies v ON e.employer_id = v.employer_id
INNER JOIN responses r ON v.vacancy_id = r.vacancy_id
GROUP BY e.employer_name
ORDER BY e.employer_name;


-- проверка для наглядности
-- SELECT e.employer_name,
--        v.vacancy_id AS vacancies,
--        r.response_id AS responses
-- FROM employers e
-- INNER JOIN vacancies v ON e.employer_id = v.employer_id
-- INNER JOIN responses r ON v.vacancy_id = r.vacancy_id
-- GROUP BY e.employer_name, v.vacancy_id, r.response_id
-- ORDER BY e.employer_name;

-- Вывод:
-- LEFT JOIN вернул 12 работодателей, INNER JOIN вернул 11 работодателей. Из результата INNER пропал ГринЭнерго: 
-- его единственная вакансия не получила ни одного отклика. Кроме того, INNER исключил 10 вакансий без откликов,
-- поэтому у многих работодателей число вакансий занижено (например, у Питер Ритейл 1 вместо 3, у СибирьТелеком 1 вместо 4).
-- Число откликов в обоих запросах одинаково. Значит, для анализа охвата работодателей и числа вакансий нужен LEFT JOIN, 
-- а INNER JOIN искажает картину, скрывая вакансии и компании без откликов.


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
-- Больше всего откликов пришлось на июль. Наибольшая конверсия в приглашение — в июне (19,5%, 23 приглашений из 118 откликов).
-- Самая низкая конверсия — в августе. Меньше всего откликов было в январе.


-- ЗАДАНИЕ Д2
-- Запрос: таблица по направлениям (вакансии, отклики, приглашения,
-- откликов на вакансию, конверсия)

SELECT v.professional_role,
       count(DISTINCT v.vacancy_id) AS vacancies,
       count(r.response_id) AS responses,
       count(r.response_id) FILTER (WHERE r.status = 'invited') AS invited,
       round(count(r.response_id)
             / nullif(count(DISTINCT v.vacancy_id), 0), 1) AS responses_per_vacancy,
       round(100.0 * count(r.response_id) FILTER (WHERE r.status = 'invited')
             / nullif(count(r.response_id), 0), 1) AS conversion_pct
FROM vacancies v
LEFT JOIN responses r ON v.vacancy_id = r.vacancy_id
GROUP BY v.professional_role
ORDER BY conversion_pct DESC;


-- Письменные ответы:
-- 1. Совпадает ли направление с наибольшим числом вакансий с направлением
--    с наибольшей конверсией?
-- Нет, наибольшая конверсия у тестировщика, а наибольшее кол-во вакансий в аналитике данных.
-- 2. Какое направление выбрать и почему (опираясь на два столбца):
-- Целесообразно выбрать направление тестировщика, так как конверсия в отклик здесь самая высокая (35,9%), а конкуренция
-- (кол-во откликов на вакансию) почти самая низкая (5) (ниже только дата-инженер).
-- 3. Оговорка к выводу:
-- Конверсия считается по всем откликам, включая необработанные (статусы new и viewed), поэтому она занижена у тех направлений, где решений ещё нет.
-- Во-вторых, у тестировщиков и дата-инженеров откликов мало, а конверсия, посчитанная по небольшой группе, сильно зависит от каждого
-- отдельного отклика, поэтому сравнивать её с другими направлениями нужно осторожно.


-- ============================================================
-- БЛОК Е. Со звёздочкой
-- ============================================================

-- ЗАДАНИЕ Е1
-- Исходный запрос (выполнить и посмотреть результат):
SELECT v.professional_role,
count(*) AS vacancies,
sum(v.salary_from) AS total_salary,
count(r.response_id) / count(*) AS responses_per_vacancy
FROM vacancies v
JOIN responses r ON v.vacancy_id = r.vacancy_id
WHERE v.closed_at = NULL
GROUP BY 1;
-- Результат - пустая таблица
--
-- Ошибки (минимум четыре):
-- 1. WHERE v.closed_at = NULL. Сравнение с NULL через = никогда не истинно, поэтому не проходит ни одна строка.
-- 2. (INNER) JOIN responses r ON v.vacancy_id = r.vacancy_id . Вакансии без откликов теряются.
-- 3. count(*) AS vacancies после INNER JOIN. Строка вакансии размножается по числу её откликов, поэтому count(*) считает отклики, а не вакансии.
-- 4. count(r.response_id) / count(*). После JOIN оба значения равны числу строк, и результат всегда 1.
-- 5. sum(v.salary_from) - непонятная метрика. Просто суммирует зарплату по всем откликам, а не по вакансиям.

-- Исправленный запрос:
SELECT v.professional_role,
       count(DISTINCT v.vacancy_id) AS vacancies,
	   round(avg(v.salary_from), 1) AS avg_salary,
       round(count(r.response_id)
             / nullif(count(DISTINCT v.vacancy_id), 0)) AS responses_per_vacancy
FROM vacancies v
LEFT JOIN responses r ON r.vacancy_id = v.vacancy_id
WHERE v.closed_at is NULL
GROUP BY v.professional_role;


-- Какие два правила из лекции защитили бы от этих ошибок при написании запроса:
-- 1. сравнение с NULL никогда не истинно — пустоту проверяют оператором IS NULL
-- 2. 