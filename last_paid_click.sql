SELECT DISTINCT
    s.visitor_id,
    s.visit_date,
    l.lead_id,
    l.created_at,
    l.amount,
    l.closing_reason,
    l.status_id,
    COALESCE(ya.utm_source, vk.utm_source) AS utm_source,
    COALESCE(ya.utm_medium, vk.utm_medium) AS utm_medium,
    COALESCE(ya.utm_campaign, vk.utm_campaign) AS utm_campaign
FROM sessions AS s
LEFT JOIN leads AS l ON s.visitor_id = l.visitor_id
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
    (
        ya.utm_medium IN ('cpc', 'cpm', 'cpa', 'youtube', 'cpp', 'tg', 'social')
        OR vk.utm_medium IN (
            'cpc', 'cpm', 'cpa', 'youtube', 'cpp', 'tg', 'social'
        )
    )
ORDER BY
    l.amount DESC NULLS LAST,
    s.visit_date ASC,
    COALESCE(ya.utm_source, vk.utm_source) ASC,
    COALESCE(ya.utm_medium, vk.utm_medium) ASC,
    COALESCE(ya.utm_campaign, vk.utm_campaign) ASC;
