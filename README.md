# E-commerce Conversion Funnel Analysis

## Project Overview
This project analyzes an e-commerce conversion funnel to identify where users drop off, quantify estimated revenue leakage, and highlight high-impact segments for optimization. The analysis combines SQL-based data modeling with Power BI dashboards to support data-driven operational decisions.

---

## Business Problem
E-commerce platforms often lose potential revenue due to friction at different stages of the customer journey. This project aims to answer:
- Where do users drop out of the funnel?
- Which stages contribute most to revenue risk?
- Which segments (device, category, price) should be prioritized?

---

## Data & Methodology
- Built a **time-ordered customer funnel** (View → Cart → Checkout → Purchase)
- Cleaned and validated event-level data to remove duplicates and invalid records
- Estimated **revenue at risk** using average order value
- Segmented performance by device type, product category, and price band

---

## Key Insights
- The largest user drop-off occurs immediately after product views, indicating early-stage engagement issues.
- Mobile users consistently underperform compared to desktop users.
- Revenue leakage is largely platform-wide rather than category-specific.
- Higher price bands show greater hesitation at the view-to-cart stage.
- Data cleaning improved metric accuracy without changing directional insights.

---

## Dashboards
The Power BI dashboard contains three pages:

1. **Executive Summary**
   - Funnel conversion rate
   - Total revenue and estimated revenue at risk

2. **Funnel Drop-offs & Revenue Leakage**
   - Stage-wise user drop-offs
   - Estimated revenue at risk by funnel stage

3. **Segmentation Analysis**
   - Conversion by device
   - View-to-cart conversion by category and price band

Dashboard screenshots are available in the `dashboard/` folder.

---

## Tools Used
- SQL (MySQL)
- Power BI
- Git & GitHub

---

## Assumptions & Limitations
- Revenue leakage is estimated using average order value.
- Funnel analysis is conducted at the customer level, not session level.
- Dataset is simulated and may not capture all real-world behaviors.

---

## Author
**Ishika Shandilya**  
