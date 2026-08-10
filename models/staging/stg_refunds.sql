with source as (

    select * from {{ source('raw', 'raw_refunds') }}

),

renamed as (

    select
        refund_id,
        order_id,
        payment_id,
        refund_amount,
        upper(currency)       as currency,
        lower(refund_reason)  as refund_reason,
        lower(refund_status)  as refund_status,
        requested_at,
        processed_at          as refunded_at

    from source

)

select * from renamed