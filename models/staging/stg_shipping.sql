with source as (

    select * from {{ source('raw', 'raw_shipping') }}

),

renamed as (

    select
        shipment_id,
        order_id,
        lower(carrier)  as carrier,
        shipping_cost,
        lower(status)   as shipment_status,
        shipped_at,
        delivered_at

    from source

)

select * from renamed