with bridge as (

    select * from {{ ref('rpt_revenue_bridge') }}

),

totals as (

    select
        sum(case when step < 7 then amount else 0 end) as sum_of_steps,
        max(case when step = 7 then amount end)        as stated_total
    from bridge

)

select *
from totals
where abs(sum_of_steps - stated_total) > 0.01