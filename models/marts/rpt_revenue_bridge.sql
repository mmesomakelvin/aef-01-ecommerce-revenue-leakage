with orders as (

    select * from {{ ref('int_order_revenue') }}

),

agg as (

    select
        sum(case when revenue_category = 'cancelled_but_charged' then payment_amount else 0 end) as cancelled_charged,
        sum(case when revenue_category = 'placed_but_charged'    then payment_amount else 0 end) as placed_charged,
        sum(case when revenue_category = 'charged_not_shipped'   then payment_amount else 0 end) as not_shipped,
        sum(case when revenue_category = 'recognisable'          then refund_amount  else 0 end) as refunds_on_good,
        sum(case when revenue_category = 'recognisable'
                 then coalesce(gateway_fee, 0) else 0 end)                                       as fees_recognised,
        sum(case when revenue_category <> 'recognisable'
                 then coalesce(gateway_fee, 0) else 0 end)                                       as fees_wasted,
        sum(recognised_revenue)                                                                  as recognised
    from orders

),

gateway as (

    select sum(payment_amount) as gateway_total
    from {{ ref('stg_payments') }}
    where payment_status = 'succeeded'

),

deduped as (

    select sum(payment_amount) as deduped_total
    from {{ ref('int_payments_deduplicated') }}

)

select 1 as step, 'Gateway total: all successful payments' as line_item,
       round(g.gateway_total, 2) as amount
from gateway g

union all
select 2, 'Less: duplicate payment webhooks',
       round(-(g.gateway_total - d.deduped_total), 2)
from gateway g cross join deduped d

union all
select 3, 'Less: cancelled orders that were charged', round(-a.cancelled_charged, 2) from agg a
union all
select 4, 'Less: placed orders that were charged',    round(-a.placed_charged, 2)    from agg a
union all
select 5, 'Less: charged, no shipping evidence',      round(-a.not_shipped, 2)       from agg a
union all
select 6, 'Less: refunds on recognised orders',       round(-a.refunds_on_good, 2)   from agg a
union all
select 7, 'Defensible revenue (mixed currency)',      round(a.recognised, 2)         from agg a

union all
select 8, 'Less: payment processing fees on recognised revenue',
       round(-a.fees_recognised, 2) from agg a
union all
select 9, 'Revenue net of payment processing costs',
       round(a.recognised - a.fees_recognised, 2) from agg a
union all
select 10, 'Memo: fees paid on revenue that was not recognised (sunk)',
       round(-a.fees_wasted, 2) from agg a

order by step