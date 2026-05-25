WITH visitors_with_leads AS (
    SELECT
        s.visitor_id,
        s.visit_date,
        l.lead_id,
        l.created_at,
        l.amount,
        l.closing_reason,
        l.status_id,
        s.medium AS utm_medium,
        s.campaign AS utm_campaign,
        LOWER(s.source) AS utm_source,
        ROW_NUMBER() OVER (
            PARTITION BY s.visitor_id
            ORDER BY s.visit_date DESC
        ) AS rn
    FROM sessions AS s
    LEFT JOIN leads AS l
        ON
            s.visitor_id = l.visitor_id
            AND s.visit_date <= l.created_at
    WHERE s.medium != 'organic'
),

aggregated AS (
    SELECT
        utm_source,
        utm_medium,
        utm_campaign,
        DATE(visit_date) AS visit_date,
        COUNT(visitor_id) AS visitors_count,
        COUNT(lead_id) AS leads_count,
        COUNT(
            CASE
                WHEN status_id = 142 THEN 1
            END
        ) AS purchases_count,
        SUM(
            CASE
                WHEN status_id = 142 THEN amount
                ELSE 0
            END
        ) AS revenue
    FROM visitors_with_leads
    WHERE rn = 1
    GROUP BY
        utm_source,
        utm_medium,
        utm_campaign,
        DATE(visit_date)
),

market AS (
    SELECT
        DATE(campaign_date) AS visit_date,
        utm_source,
        utm_medium,
        utm_campaign,
        SUM(daily_spent) AS total_cost
    FROM ya_ads
    GROUP BY
        visit_date,
        utm_source,
        utm_medium,
        utm_campaign
    UNION ALL
    SELECT
        DATE(campaign_date) AS visit_date,
        utm_source,
        utm_medium,
        utm_campaign,
        SUM(daily_spent) AS total_cost
    FROM vk_ads
    GROUP BY
        visit_date,
        utm_source,
        utm_medium,
        utm_campaign
)

SELECT
    a.visit_date,
    a.visitors_count,
    a.utm_source,
    a.utm_medium,
    a.utm_campaign,
    m.total_cost,
    a.leads_count,
    a.purchases_count,
    a.revenue
FROM aggregated AS a
LEFT JOIN market AS m
    ON
        a.visit_date = m.visit_date
        AND a.utm_source = m.utm_source
        AND a.utm_medium = m.utm_medium
        AND a.utm_campaign = m.utm_campaign
ORDER BY
    a.revenue DESC NULLS LAST,
    a.visit_date ASC,
    a.visitors_count DESC,
    a.utm_source ASC,
    a.utm_medium ASC
LIMIT 15;
