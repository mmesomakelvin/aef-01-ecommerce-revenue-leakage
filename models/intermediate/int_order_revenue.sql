with orders as (

    select * from {{ ref('stg_orders') }}

),

payments as (

    select * from {{ ref('int_payments_deduplicated') }}

),

refunds as (

    select
        order_id,
        sum(refund_amount) as refund_amount,
        min(refunded_at)   as first_refunded_at
    from {{ ref('stg_refunds') }}
    where refund_status = 'completed'
    group by order_id

),

shipping as (

    select * from {{ ref('stg_shipping') }}

),

joined as (

    select
        o.order_id,
        o.customer_id,
        o.order_status,
        o.currency,
        o.order_amount,
        o.ordered_at,

        p.payment_amount,
        p.gateway_fee,
        p.processed_at                as paid_at,

        coalesce(r.refund_amount, 0)  as refund_amount,
        r.first_refunded_at           as refunded_at,

        s.shipped_at,
        s.delivered_at

    from orders o
    left join payments p on o.order_id = p.order_id
    left join refunds  r on o.order_id = r.order_id
    left join shipping s on o.order_id = s.order_id

),

classified as (

    select
        *,
        case
            when payment_amount is null     then 'never_charged'
            when order_status = 'cancelled' then 'cancelled_but_charged'
            when order_status = 'placed'    then 'placed_but_charged'
            when shipped_at is null       
            and delivered_at is null  
            then 'charged_not_shipped'
            else                                 'recognisable'
        end as revenue_category
    from joined

)

select
    *,
    case
        when revenue_category = 'recognisable'
        then payment_amount - refund_amount
        else 0
    end as recognised_revenue

from classified