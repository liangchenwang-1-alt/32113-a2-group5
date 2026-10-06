-- 32113 A2 / Workbook Part 1 section 1.2.1 CHALLENGE ACTIVITY
-- "Create a second table 'shops' that stores information about different IT stores in Australia.
--  Each entry should have information about the shop's name, address (including street, state,
--  postcode), shop's phone number and shop's email address.
--  Populate the table with three different entries of three different stores in
--  different states in Australia. Present the results to your tutor."
--
-- NOTE: the data below is synthetic sample data for the lab exercise (no real business data).

DROP TABLE IF EXISTS shops;

CREATE TABLE shops (
  shop_id     SERIAL PRIMARY KEY,
  shop_name   VARCHAR(120) NOT NULL,
  street      VARCHAR(120) NOT NULL,
  state       CHAR(3)      NOT NULL,   -- NSW / VIC / QLD
  postcode    CHAR(4)      NOT NULL,
  phone       VARCHAR(20)  NOT NULL,
  email       VARCHAR(120) NOT NULL
);

INSERT INTO shops (shop_name, street, state, postcode, phone, email) VALUES
  ('Sydney Tech Warehouse', '12 Pitt Street',        'NSW', '2000', '02 9000 1000', 'sales@sydneytech.example'),
  ('Melbourne Computer Hub', '88 Bourke Street',     'VIC', '3000', '03 9000 2000', 'sales@melbcomputer.example'),
  ('Brisbane IT Supplies',   '45 Queen Street',      'QLD', '4000', '07 3000 3000', 'sales@bneitsupplies.example');

SELECT shop_id, shop_name, street, state, postcode, phone, email FROM shops ORDER BY shop_id;