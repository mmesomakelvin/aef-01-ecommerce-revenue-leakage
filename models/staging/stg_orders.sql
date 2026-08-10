with source as (

    select * from {{ source('raw', 'raw_orders') }}

),

renamed as (

    select
        order_id,
        customer_id,
        lower(order_status)  as order_status,
        order_amount,
        upper(currency)      as currency,
        created_at           as ordered_at,
        updated_at           as status_updated_at

    from source

)

select * from renamed