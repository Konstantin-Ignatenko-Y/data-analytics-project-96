WITH paid_visits AS (
    SELECT
        s.visitor_id,
        s.visit_date,
        COALESCE(ya.utm_source, vk.utm_source) AS utm_source,
        COALESCE(ya.utm_medium, vk.utm_medium) AS utm_medium,
        COALESCE(ya.utm_campaign, vk.utm_campaign) AS utm_campaign,
		-- Реализуем счетчик для вычисления последнего платного клика
        ROW_NUMBER() OVER (
            PARTITION BY s.visitor_id
            ORDER BY s.visit_date DESC
        ) AS rn
    FROM sessions AS s
    LEFT JOIN ya_ads AS ya
        ON
            s.source = ya.utm_source
            AND s.medium = ya.utm_medium
            AND s.campaign = ya.utm_campaign
            AND s.content = ya.utm_content
    LEFT JOIN vk_ads AS vk
        ON
            s.source = vk.utm_source
            AND s.medium = vk.utm_medium
            AND s.campaign = vk.utm_campaign
            AND s.content = vk.utm_content
    WHERE
        ya.utm_medium <> 'organic' OR vk.utm_medium <> 'organic'
),

last_paid_click AS (
    SELECT *
    FROM paid_visits
    WHERE rn = 1
), 

attribution_data AS (
    SELECT DISTINCT
        lpc.visitor_id,
        lpc.visit_date,
        lpc.utm_source,
        lpc.utm_medium,
        lpc.utm_campaign,
        l.lead_id,
        l.created_at,
        l.amount,
        l.closing_reason,
        l.status_id
    FROM last_paid_click AS lpc
    LEFT JOIN leads AS l
        ON
            lpc.visitor_id = l.visitor_id
            AND (lpc.visit_date <= l.created_at OR l.created_at IS NULL)
    ORDER BY
        l.amount DESC NULLS LAST,
        lpc.visit_date ASC,
        lpc.utm_source ASC,
        lpc.utm_medium ASC,
        lpc.utm_campaign ASC
),

ad_costs AS (
    -- Суммируем затраты из ya_ads по дате и UTM меткам
    SELECT
        campaign_date::DATE AS visit_date,
        utm_source,
        utm_medium,
        utm_campaign,
        SUM(daily_spent) AS total_cost
    FROM ya_ads
    WHERE utm_medium <> 'organic'
    GROUP BY campaign_date::DATE, utm_source, utm_medium, utm_campaign
    UNION ALL
    -- Суммируем затраты из vk_ads по дате и UTM меткам
    SELECT
        campaign_date::DATE AS visit_date,
        utm_source,
        utm_medium,
        utm_campaign,
        SUM(daily_spent) AS total_cost
    FROM vk_ads
    WHERE utm_medium <> 'organic'
    GROUP BY campaign_date::DATE, utm_source, utm_medium, utm_campaign
)

-- Основной запрос: агрегируем данные по дням и меткам
SELECT
    ad.visit_date,
    ad.utm_source,
    ad.utm_medium,
    ad.utm_campaign,
    COUNT(ad.visitor_id) AS visitors_count,
    COALESCE(ac.total_cost, 0) AS total_cost,
    COUNT(DISTINCT ad.lead_id) AS leads_count,
    COUNT(DISTINCT CASE
        WHEN ad.closing_reason = 'Успешно реализовано' OR ad.status_id = 142
            THEN ad.lead_id
    END) AS purchases_count,
    COALESCE(SUM(CASE
        WHEN ad.closing_reason = 'Успешно реализовано' OR ad.status_id = 142
            THEN ad.amount
        ELSE 0
    END), 0) AS revenue
FROM attribution_data AS ad
LEFT JOIN ad_costs AS ac
    ON
        ad.visit_date = ac.visit_date
        AND ad.utm_source = ac.utm_source
        AND ad.utm_medium = ac.utm_medium
        AND ad.utm_campaign = ac.utm_campaign
GROUP BY
    ad.visit_date, ad.utm_source, ad.utm_medium, ad.utm_campaign, ac.total_cost
ORDER BY
    revenue DESC NULLS LAST,
    visit_date ASC,
    visitors_count DESC,
    utm_source ASC,
    utm_medium ASC,
    utm_campaign ASC;
