SET search_path TO bookings;

--1. Выведите название самолетов, которые имеют менее 50 посадочных мест

--Решение
select t1.model as "модель самолета", t1.count as "количество мест"
from
(select count(a.aircraft_code), a.model
           from aircrafts a
           join seats s on a.aircraft_code = s.aircraft_code
           group by a.aircraft_code
           order by a.aircraft_code) t1
where t1.count <50



--2. Выведите процентное изменение ежемесячной суммы бронирования билетов, округленной до сотых.

--Решение
select (t2.date::date) as "месяц", t2.sum as "сумма за месяц", round(((t2.sum-t2.lag)/t2.lag)*100, 2) as "%"
from
(select *, lag (t1.sum) over (order by t1.date) 
   from 
(select date_trunc ('month', b.book_date::timestamptz) as "date", sum(b.total_amount)
   from bookings b
   group by date_trunc ('month', b.book_date::timestamptz)
order by date_trunc ('month', b.book_date::timestamptz)) t1) t2




--3. Выведите названия самолетов не имеющих бизнес - класс. Решение должно быть через функцию array_agg.

--Решение
select t1.model, t1.klass
from 
(select a.aircraft_code,a.model, array_agg(distinct s.fare_conditions) as "klass"
from aircrafts a
join seats s on a.aircraft_code = s.aircraft_code
group by a.model, a.aircraft_code 
order by a.model) t1
WHERE 'Business' != ALL(t1.klass)




--4. Вывести накопительный итог количества мест в самолетах по каждому аэропорту на каждый день,
-- учитывая только те самолеты, которые летали пустыми и только те дни, где из одного аэропорта таких самолетов вылетало более одного.
--В результате должны быть 
--код аэропорта, дата, количество пустых мест в самолете и накопительный итог мест
-- Более 1 самолета в день

--Логика у меня была такая. 
--1. Пустые самолеты - это рейсы, которые есть в таблице flights, но которых нет в таблице boarding_passes
--2. Посчитала отдельно ко-во мест в таблице seats и приджоинила эту таблицу к общей.
--3. Нашла вылеты более одного в день. Для этого посчитала через оконную функцию кол-во дат, и отобрала какие более одной. 
-- С помощью оконной функции нашла накопительный итог по местам.
--Сортировала по аэропортам.

--Решение
select t3.departure_airport as "код аэропорта", t3.actual_departure as "дата", t3.col_vo_mest as "кол-во пустых мест", t3.itog as "накопительный итог мест"
from
(select *, sum(t2.col_vo_mest) over (partition by t2.departure_airport  order by t2.flight_id) as "itog"
from 
(select f.flight_id, f.departure_airport, f.status, f.actual_departure::date, t1.aircraft_code, t1.col_vo_mest, count(f.actual_departure) over (partition by f.actual_departure order by f.actual_departure)   
from flights f 
join (select aircraft_code,count(aircraft_code) col_vo_mest
      from seats s 
      group by aircraft_code) t1 on f.aircraft_code = t1.aircraft_code
full join boarding_passes bp on f.flight_id = bp.flight_id
where f.flight_id is null or bp.flight_id is null)t2
where t2.count !=1 and t2.actual_departure is not null
order by t2.departure_airport) t3


--5. Найдите процентное соотношение перелетов по маршрутам от общего количества перелетов.
--Выведите в результат названия аэропортов и процентное отношение.
-- Решение должно быть через оконную функцию.

--Решение
select t1.concat as "аэропорты", t1.round as "%_соотношение"
from 
(select concat(a1.airport_name, '-', a.airport_name), count(*), sum(count(*)) over (), round((((count(*))/(sum(count(*)) over ())*100)), 3)   
from flights f
join airports a on a.airport_code = f.arrival_airport
join airports a1 on a1.airport_code = f.departure_airport 
group by a1.airport_name, a.airport_name) t1




--6. Выведите количество пассажиров по каждому коду сотового оператора, если учесть, что код оператора - это три символа после +7

--Решение
select substring((contact_data ->>'phone') from 3 for 3) as "код оператора" , count(*) as "количество пассажиров"
from tickets t 
group by substring((contact_data ->>'phone') from 3 for 3)
order by substring((contact_data ->>'phone') from 3 for 3) asc


--7. Классифицируйте финансовые обороты (сумма стоимости перелетов) по маршрутам:
-- До 50 млн - low
--От 50 млн включительно до 150 млн - middle
-- От 150 млн включительно - high
--Выведите в результат количество маршрутов в каждом полученном классе


--Решение
select t2.case as "класс", count(*) as "количество маршрутов" 
from 
(select *, case when (t1.sum) < 50000000 then 'low' 
when (t1.sum) >= 50000000 and (t1.sum) < 150000000 then 'middle'
when  (t1.sum) >= 150000000 then 'high' end 
from 
(select concat(f.departure_airport, '-', f.arrival_airport) as "маршрут", sum(tf.amount)
   from flights f
   join ticket_flights tf on f.flight_id = tf.flight_id
   group by concat(f.departure_airport, '-', f.arrival_airport)) t1) t2
group by t2.case
	

--8. Вычислите медиану стоимости перелетов, медиану размера бронирования и отношение медианы бронирования к медиане стоимости перелетов, округленной до сотых

--Решение
select t1.percentile_cont::int as "медиана размера бронирования", t2.percentile_cont::int as "медиана стоимости перелетов",
round((t1.percentile_cont/t2.percentile_cont)::numeric, 2) as "отношение"
from 
(select PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY b.total_amount)
from bookings b) t1 
cross join (select PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY tf.amount)
from ticket_flights tf) t2



--9. Найдите значение минимальной стоимости полета 1 км --для пассажиров.

-- То есть нужно найти расстояние между аэропортами и с учетом стоимости перелетов получить искомый результат
-- Для поиска расстояния между двумя точками на поверхности Земли используется модуль earthdistance.
--  Для работы модуля earthdistance необходимо предварительно установить модуль cube.
--  Установка модулей происходит через команду: create extension название_модуля.

-- Николай, Вы отправляли мне это задание на доработку. "Перепутаны широта и долгота"
-- Исправила, поменяла широту и долготу в коде.


--Решение
create extension cube

create extension earthdistance

select round(min (t2.price_1_kilometer)::numeric, 3) as "минимальная стоимость полета 1 км" 
from
(select t1.*, round((earth_distance(ll_to_earth(t1.latitude_1, t1.longitude_1), ll_to_earth(t1.latitude, t1.longitude))/1000)::numeric, 2) as "kilometry", 
t1.amount/(round((earth_distance(ll_to_earth(t1.latitude_1, t1.longitude_1), ll_to_earth(t1.latitude, t1.longitude))/1000)::numeric, 2))
as "price_1_kilometer"
from 
(select f.flight_id, f.departure_airport, a.latitude as latitude_1, a.longitude as longitude_1, f.arrival_airport, a2.latitude, a2.longitude, tf.amount  
from flights f
join airports a on f.departure_airport = a.airport_code
join airports a2 on f.arrival_airport = a2.airport_code
join ticket_flights tf on tf.flight_id = f.flight_id) t1) t2


