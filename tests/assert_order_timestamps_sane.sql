{{ config(severity = 'warn') }}

select
    order_id,
    order_status,
    ordered_at,
    status_updated_at,
    datediff('hour', ordered_at, status_updated_at) as hours_difference

from {{ ref('stg_orders') }}
where status_updated_at < ordered_at