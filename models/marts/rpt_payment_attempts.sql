with orders as (

    select
        order_id,
        order_status,
        order_amount,
        currency
    from {{ ref('stg_orders') }}

),

attempts as (

    select
        order_id,
        count(*)                                                      as total_attempts,
        sum(case when payment_status = 'failed'    then 1 else 0 end) as failed_attempts,
        sum(case when payment_status = 'succeeded' then 1 else 0 end) as successful_attempts
    from {{ ref('stg_payments') }}
    group by order_id

),

joined as (

    select
        o.order_id,
        o.order_status,
        o.order_amount,
        coalesce(a.total_attempts, 0)      as total_attempts,
        coalesce(a.failed_attempts, 0)     as failed_attempts,
        coalesce(a.successful_attempts, 0) as successful_attempts,

        case
            when a.order_id is null        then 'no_payment_attempted'
            when a.successful_attempts = 0 then 'all_attempts_failed'
            when a.failed_attempts = 0     then 'first_time_success'
            else                                'recovered_after_retry'
        end as attempt_outcome

    from orders o
    left join attempts a
      on o.order_id = a.order_id

)

select
    attempt_outcome,
    count(*)                       as orders,
    sum(failed_attempts)           as failed_attempts,
    round(avg(total_attempts), 2)  as avg_attempts_per_order,
    round(sum(order_amount), 2)    as order_value

from joined
group by attempt_outcome
order by orders desc
