/* Query 1 - query used for first insight */
SELECT release_year, ct.name AS film_category, count(*) AS num_of_film
FROM film f
JOIN film_category fc
ON f.film_id = fc.film_id
JOIN category ct
ON ct.category_id = fc.category_id
WHERE release_year = 2006
GROUP BY 1,2
ORDER BY 3 DESC


/* Query 2 - query used for second insight */
SELECT ct.name AS film_category, 
	   AVG(DATE_TRUNC('day',return_date)-DATE_TRUNC('day',rental_date)) AS avg_customer_rental_duration,
	   EXTRACT(epoch FROM AVG(DATE_TRUNC('day',return_date)-DATE_TRUNC('day',rental_date))/86400) AS avg_customer_rental_duration_decimal
FROM customer c
JOIN rental r
ON c.customer_id = r.customer_id
JOIN inventory i
ON i.inventory_id = r.inventory_id
JOIN film f
ON f.film_id = i.film_id
JOIN film_category fc
ON f.film_id = fc.film_id
JOIN category ct
ON ct.category_id = fc.category_id
GROUP BY 1
ORDER BY 2 DESC


/* Query 3 - query used for third insight */
WITH customer_frequency AS(
SELECT customer_id, customer_name, 
	   NTILE(3) OVER (ORDER BY rental_count) AS rental_count_quantile
FROM(SELECT c.customer_id AS customer_id, 
	 CONCAT(first_name,' ',last_name) AS customer_name, 
	 COUNT(*) AS rental_count
	 FROM customer c
	 JOIN rental r
	 ON r.customer_id = c.customer_id
	 GROUP BY 1,2) sub1),

customer_monetary_value AS(
SELECT customer_id, customer_name, 
	   NTILE(3) OVER (ORDER BY sum_amount) AS sum_amount_quantile
FROM(SELECT c.customer_id AS customer_id, 
	 CONCAT(first_name,' ',last_name) AS customer_name, 
	 SUM(amount) AS sum_amount
	 FROM customer c
	 JOIN payment p
	 ON p.customer_id = c.customer_id
	 GROUP BY 1,2) sub2),
customer_level AS (
SELECT cf.customer_id, cf.customer_name, rental_count_quantile, sum_amount_quantile,
	   CASE WHEN rental_count_quantile = 1 THEN 'A'
			WHEN rental_count_quantile = 2 THEN 'B'
			WHEN rental_count_quantile = 3 THEN 'C'
		END AS rental_count_level
FROM customer_frequency cf
JOIN customer_monetary_value cmv
ON cf.customer_id = cmv.customer_id)

SELECT CONCAT('Level',' ',sum_amount_quantile,rental_count_level) AS Level , 
	   count(*) AS num_of_customers
FROM customer_level
GROUP BY 1
ORDER BY 2 DESC


/* Query 4 - query used for fourth insight */
WITH sub1 AS (
	SELECT country,num_of_customers, ROW_NUMBER() over (order by num_of_customers DESC) country_rank
	FROM(SELECT country, count(*) num_of_customers
		 FROM customer c
		 JOIN address a
		 ON c.address_id = a.address_id
		 JOIN city ct
		 ON ct.city_id = a.city_id
		 JOIN country co
		 ON co.country_id = ct.country_id
		 GROUP BY 1) sub ),
sub2 AS (
	SELECT DATE_PART('dow',payment_date) dow, sum(amount) sum_payment_amt
	FROM customer c
	JOIN address a
	ON c.address_id = a.address_id
	JOIN city ct
	ON ct.city_id = a.city_id
	JOIN country co
	ON co.country_id = ct.country_id
	JOIN payment p
	ON c.customer_id = p.customer_id
	WHERE country IN (SELECT country FROM sub1 WHERE country_rank IN (1,2,3,4,5))
	GROUP BY 1)
	
SELECT CASE WHEN dow = 0 THEN 'Sunday'
			WHEN dow = 1 THEN 'Monday'
			WHEN dow = 2 THEN 'Tuesday'
			WHEN dow = 3 THEN 'Wednesday'
			WHEN dow = 4 THEN 'Thursday'
			WHEN dow = 5 THEN 'Friday'
			WHEN dow = 6 THEN 'Saturday'
			END AS day_of_week,
		sum_payment_amt
FROM sub2
ORDER BY 2 DESC
