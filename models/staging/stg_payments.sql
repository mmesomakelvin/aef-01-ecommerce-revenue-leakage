with source as (

    select * from {{ source('raw', 'raw_payments') }}

),

renamed as (

    select
        payment_id,
        order_id,
        lower(payment_status)  as payment_status,
        amount                 as payment_amount,
        upper(currency)        as currency,
        lower(payment_method)  as payment_method,
        gateway_fee,
        attempted_at,
        processed_at

    from source

)

select * from renamed