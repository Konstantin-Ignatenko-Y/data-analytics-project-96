-- Сколько у нас пользователей заходят на сайт?
SELECT COUNT(DISTINCT visitor_id)
FROM sessions;

-- Какие каналы их приводят на сайт?
SELECT
    visitor_id,
    visit_date,
    source AS utm_source,
    medium AS utm_medium,
    campaign AS utm_campaign
FROM sessions
WHERE medium <> 'organic';

-- Какие каналы их приводят на сайт? Хочется видеть по дням/неделям/месяцам
-- по дням
SELECT
    source,
    medium,
    campaign,
    DATE(visit_date) AS visit_date,
    COUNT(DISTINCT visitor_id) AS visitors_count
FROM sessions
GROUP BY
    DATE(visit_date),
    source,
    medium,
    campaign
ORDER BY
    visit_date DESC,
    visitors_count DESC;

-- Какие каналы их приводят на сайт?
-- по неделям
SELECT
    source,
    medium,
    campaign,
    DATE_TRUNC('week', visit_date) AS week_start,
    TO_CHAR(DATE_TRUNC('week', visit_date), 'YYYY-WW') AS week_label,
    COUNT(DISTINCT visitor_id) AS visitors_count
FROM sessions
GROUP BY
    DATE_TRUNC('week', visit_date),
    TO_CHAR(DATE_TRUNC('week', visit_date), 'YYYY-WW'),
    source,
    medium,
    campaign
ORDER BY
    week_start DESC,
    visitors_count DESC;

-- Какие каналы их приводят на сайт?
-- по месяцам
SELECT
    source,
    medium,
    campaign,
    DATE_TRUNC('month', visit_date) AS month_start,
    TO_CHAR(visit_date, 'YYYY-MM') AS month_label,
    COUNT(DISTINCT visitor_id) AS visitors_count
FROM sessions
GROUP BY
    DATE_TRUNC('month', visit_date),
    TO_CHAR(visit_date, 'YYYY-MM'),
    source,
    medium,
    campaign
ORDER BY
    month_start DESC,
    visitors_count DESC;

-- Сколько лидов к нам приходят?
SELECT COUNT(DISTINCT visitor_id) AS total_leads
FROM leads;

-- Какая конверсия из клика в лид? А из лида в оплату?
WITH unique_clicks AS (
    SELECT COUNT(DISTINCT visitor_id) AS total_clicks
    FROM sessions
),

unique_leads AS (
    SELECT COUNT(DISTINCT visitor_id) AS total_leads
    FROM leads
),

successful_conversions AS (
    SELECT COUNT(DISTINCT visitor_id) AS successful_purchases
    FROM leads
    WHERE
        status_id = 142
        OR closing_reason = 'Успешно реализовано'
)

SELECT
    -- Конверсия из клика в лид: лиды / клики
    ROUND(
        CAST(ul.total_leads AS NUMERIC) / uc.total_clicks * 100,
        2
    ) AS click_to_lead_conversion_pct,

    -- Конверсия из лида в оплату: успешные покупки / лиды
    ROUND(
        CAST(sc.successful_purchases AS NUMERIC) / ul.total_leads * 100,
        2
    ) AS lead_to_purchase_conversion_pct

FROM unique_clicks AS uc
CROSS JOIN unique_leads AS ul
CROSS JOIN successful_conversions AS sc;

-- Сколько мы тратим по разным каналам в динамике?
-- по дням
SELECT
    campaign_date,
    utm_source AS source,
    utm_medium AS medium,
    utm_campaign AS campaign,
    SUM(daily_spent) AS daily_spent
FROM vk_ads
GROUP BY
    campaign_date,
    utm_source,
    utm_medium,
    utm_campaign
UNION ALL
SELECT
    campaign_date,
    utm_source AS source,
    utm_medium AS medium,
    utm_campaign AS campaign,
    SUM(daily_spent) AS daily_spent
FROM ya_ads
GROUP BY
    campaign_date,
    utm_source,
    utm_medium,
    utm_campaign;

-- Сколько мы тратим по разным каналам в динамике?	
-- по неделям
SELECT
    DATE_TRUNC('week', campaign_date) AS week_start,
    TO_CHAR(DATE_TRUNC('week', campaign_date), 'YYYY-WW') AS week_label,
    utm_source AS source,
    utm_medium AS medium,
    utm_campaign AS campaign,
    SUM(daily_spent) AS weekly_spent
FROM vk_ads
GROUP BY
    DATE_TRUNC('week', campaign_date),
    TO_CHAR(DATE_TRUNC('week', campaign_date), 'YYYY-WW'),
    utm_source,
    utm_medium,
    utm_campaign

UNION ALL

SELECT
    DATE_TRUNC('week', campaign_date) AS week_start,
    TO_CHAR(DATE_TRUNC('week', campaign_date), 'YYYY-WW') AS week_label,
    utm_source AS source,
    utm_medium AS medium,
    utm_campaign AS campaign,
    SUM(daily_spent) AS weekly_spent
FROM ya_ads
GROUP BY
    DATE_TRUNC('week', campaign_date),
    TO_CHAR(DATE_TRUNC('week', campaign_date), 'YYYY-WW'),
    utm_source,
    utm_medium,
    utm_campaign
ORDER BY week_start DESC, weekly_spent DESC;

-- Сколько мы тратим по разным каналам в динамике?
-- по месяцам
SELECT
    DATE_TRUNC('month', campaign_date) AS month_start,
    TO_CHAR(campaign_date, 'YYYY-MM') AS month_label,
    utm_source AS source,
    utm_medium AS medium,
    utm_campaign AS campaign,
    SUM(daily_spent) AS monthly_spent
FROM vk_ads
GROUP BY
    DATE_TRUNC('month', campaign_date),
    TO_CHAR(campaign_date, 'YYYY-MM'),
    utm_source,
    utm_medium,
    utm_campaign

UNION ALL

SELECT
    DATE_TRUNC('month', campaign_date) AS month_start,
    TO_CHAR(campaign_date, 'YYYY-MM') AS month_label,
    utm_source AS source,
    utm_medium AS medium,
    utm_campaign AS campaign,
    SUM(daily_spent) AS monthly_spent
FROM ya_ads
GROUP BY
    DATE_TRUNC('month', campaign_date),
    TO_CHAR(campaign_date, 'YYYY-MM'),
    utm_source,
    utm_medium,
    utm_campaign
ORDER BY month_start DESC, monthly_spent DESC;

-- Расчет основных метрик
WITH last_paid_click AS (
    SELECT
        s.visitor_id,
        s.visit_date,
        s.source AS utm_source,
        s.medium AS utm_medium,
        s.campaign AS utm_campaign,
        l.lead_id,
        l.created_at,
        l.amount,
        l.closing_reason,
        l.status_id,
        ROW_NUMBER() OVER (
            PARTITION BY s.visitor_id ORDER BY s.visit_date DESC
        ) AS rn
    FROM
        sessions AS s
    LEFT JOIN
        leads AS l
        ON s.visitor_id = l.visitor_id AND s.visit_date <= l.created_at
    WHERE s.medium <> 'organic'
),

ads AS (
    SELECT
        campaign_date,
        utm_source,
        utm_medium,
        utm_campaign,
        SUM(daily_spent) AS daily_spent
    FROM ya_ads
    GROUP BY
        campaign_date,
        utm_source,
        utm_medium,
        utm_campaign
    UNION ALL
    SELECT
        campaign_date,
        utm_source,
        utm_medium,
        utm_campaign,
        SUM(daily_spent) AS daily_spent
    FROM vk_ads
    GROUP BY
        campaign_date,
        utm_source,
        utm_medium,
        utm_campaign
),

lpc AS (
    SELECT
        lpc.utm_source,
        lpc.utm_medium,
        lpc.utm_campaign,
        CAST(visit_date AS DATE) AS visit_date,
        COUNT(lpc.visitor_id) AS visitors_count,
        COUNT(lpc.lead_id) AS leads_count,
        COUNT(
            CASE WHEN lpc.status_id = 142 THEN 1 END
        ) AS purchases_count,
        SUM(lpc.amount) AS revenue
    FROM
        last_paid_click AS lpc
    WHERE
        lpc.rn = 1
    GROUP BY
        CAST(visit_date AS DATE),
        lpc.utm_source,
        lpc.utm_medium,
        lpc.utm_campaign
)

SELECT
    ads.utm_source,
    ROUND(
        SUM(ads.daily_spent) / NULLIF(SUM(lpc.visitors_count), 0), 2
    ) AS cpu,
    ROUND(
        SUM(ads.daily_spent) / NULLIF(SUM(lpc.leads_count), 0), 2
    ) AS cpl,
    ROUND(
        SUM(ads.daily_spent) / NULLIF(SUM(lpc.purchases_count), 0), 2
    ) AS cppu,
    -- Окупаются ли каналы? (Если ROI > 0% то каналы окупаются)
    ROUND(
        (
            (SUM(lpc.revenue) - SUM(ads.daily_spent))
            / NULLIF(SUM(ads.daily_spent), 0)
        ) * 100, 2
    ) AS roi
FROM lpc
LEFT JOIN ads
    ON
        CAST(ads.campaign_date AS DATE) = CAST(lpc.visit_date AS DATE)
        AND lpc.utm_source = ads.utm_source
        AND lpc.utm_medium = ads.utm_medium
        AND lpc.utm_campaign = ads.utm_campaign
WHERE ads.utm_source IS NOT NULL
GROUP BY ads.utm_source;
