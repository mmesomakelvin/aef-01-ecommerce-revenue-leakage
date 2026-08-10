with recognised as (

    select * from {{ ref('int_order_revenue') }}
    where revenue_category = 'recognisable'

),

refunds as (

    select
        order_id,
        refund_amount,
        refunded_at
    from {{ ref('stg_refunds') }}
    where refund_status = 'completed'

),

sales as (

    select
        date_trunc('month', paid_at) as month,
        sum(payment_amount)          as gross_revenue
    from recognised
    group by 1

),

refunds_as_booked as (

    select
        date_trunc('month', f.refunded_at) as month,
        sum(f.refund_amount)               as refunds
    from refunds f
    join recognised o on o.order_id = f.order_id
    group by 1

),

refunds_matched as (

    select
        date_trunc('month', o.paid_at) as month,
        sum(f.refund_amount)           as refunds
    from refunds f
    join recognised o on o.order_id = f.order_id
    group by 1

),

months as (

    select month from sales
    union
    select month from refunds_as_booked

)

select
    mo.month,
    round(coalesce(s.gross_revenue, 0), 2)                              as gross_revenue,
    round(coalesce(b.refunds, 0), 2)                                    as refunds_as_booked,
    round(coalesce(m.refunds, 0), 2)                                    as refunds_matched_to_sale,
    round(coalesce(s.gross_revenue, 0) - coalesce(b.refunds, 0), 2)     as net_as_reported,
    round(coalesce(s.gross_revenue, 0) - coalesce(m.refunds, 0), 2)     as net_matched,
    round(coalesce(b.refunds, 0) - coalesce(m.refunds, 0), 2)           as distortion
from months mo
left join sales             s on mo.month = s.month
left join refunds_as_booked b on mo.month = b.month
left join refunds_matched   m on mo.month = m.month
order by mo.month