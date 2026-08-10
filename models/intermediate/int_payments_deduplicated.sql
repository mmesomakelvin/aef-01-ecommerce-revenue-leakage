with successful_payments as (

    select * from {{ ref('stg_payments') }}
    where payment_status = 'succeeded'

),

ranked as (

    select
        *,
        row_number() over (
            partition by order_id
            order by processed_at, payment_id
        ) as payment_rank

    from successful_payments

)

select
    payment_id,
    order_id,
    payment_amount,
    currency,
    payment_method,
    gateway_fee,
    attempted_at,
    processed_at

from ranked
where payment_rank = 1