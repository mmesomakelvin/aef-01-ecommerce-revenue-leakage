with orders as (

    select * from {{ ref('int_order_revenue') }}

),

gateway as (

    select
        currency,
        sum(payment_amount) as gateway_total
    from {{ ref('stg_payments') }}
    where payment_status = 'succeeded'
    group by currency

),

deduped as (

    select
        currency,
        sum(payment_amount) as deduped_total
    from {{ ref('int_payments_deduplicated') }}
    group by currency

),

agg as (

    select
        currency,
        sum(case when revenue_category = 'cancelled_but_charged' then payment_amount else 0 end) as cancelled_charged,
        sum(case when revenue_category = 'placed_but_charged'    then payment_amount else 0 end) as placed_charged,
        sum(case when revenue_category = 'charged_not_shipped'   then payment_amount else 0 end) as not_shipped,
        sum(case when revenue_category = 'recognisable'          then refund_amount  else 0 end) as refunds_on_good,
        sum(recognised_revenue)                                                                  as recognised
    from orders
    group by currency

)

select
    g.currency,
    round(g.gateway_total, 2)                       as gateway_total,
    round(-(g.gateway_total - d.deduped_total), 2)  as duplicate_webhooks,
    round(-a.cancelled_charged, 2)                  as cancelled_but_charged,
    round(-a.placed_charged, 2)                     as placed_but_charged,
    round(-a.not_shipped, 2)                        as no_shipping_evidence,
    round(-a.refunds_on_good, 2)                    as refunds,
    round(a.recognised, 2)                          as defensible_revenue,
    round(g.gateway_total - a.recognised, 2)        as overstatement

from gateway g
join deduped d on g.currency = d.currency
join agg     a on g.currency = a.currency
order by defensible_revenue desc