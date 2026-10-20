import duckdb, pathlib
def run(f, setup, sub=None):
    c=duckdb.connect(); c.execute(setup)
    q=pathlib.Path(f).read_text()
    if sub: q=q.replace(*sub).replace('TO_CHAR','strftime')
    print('==',f); print(c.execute(q).fetchdf().to_string(index=False))
run('01_dedup.sql',"""create table customers(customer_id int,email varchar,name varchar,phone varchar,updated_at date);
insert into customers values(3,'bob@example.com','Bob Brown','555-2002','2024-01-05'),(5,'bob@example.com','Bob B','555-2002','2024-01-25'),(6,'david@example.com','David D','555-4004','2024-01-12'),(8,'eve@example.com','Eve E','555-5005','2024-01-08'),(11,'bob@example.com','Bob Beta','555-2002','2024-01-28'),(16,'david@example.com','David Davis','555-4004','2024-01-22'),(21,null,'Unknown','555-0012','2024-01-17')""")
run('02_running_total.sql',"""create table scores(day int,gender varchar,player_name varchar,score_points int);
insert into scores values(1,'F','A',10),(2,'F','B',20),(3,'F','C',15),(4,'F','D',25),(1,'M','Bob',15),(1,'M','Charlie',12),(2,'M','E',18),(3,'M','G',22)""",('ctid','rowid'))
run('03_yoy_growth.sql',"""create table hosts(country varchar,host_id int,host_name varchar,signup_date date);
insert into hosts values('x',1,'a','2020-01-01'),('x',2,'a','2020-03-01'),('x',3,'a','2020-05-01'),('x',4,'a','2021-01-01'),('x',5,'a','2021-02-01'),('x',6,'a','2021-03-01'),('x',7,'a','2021-04-01'),('x',8,'a','2022-01-01')""")
run('04_gaps_islands.sql',"""create table logins(login_id int,user_id int,login_date date);
insert into logins values(1,1,'2024-01-01'),(2,1,'2024-01-02'),(3,1,'2024-01-02'),(4,1,'2024-01-03'),(5,2,'2024-01-01'),(6,2,'2024-01-02'),(7,3,'2024-01-05'),(8,3,'2024-01-06'),(9,3,'2024-01-07')""")
run('05_sessionization.sql',"""create table events(event_id int,user_id int,event_type varchar,event_timestamp timestamp);
insert into events values(1,2001,'v','2024-01-01 10:00'),(2,2001,'v','2024-01-01 10:31'),(3,2001,'v','2024-01-01 10:55'),(4,2001,'v','2024-01-01 11:06'),(5,2001,'v','2024-01-01 11:12'),(6,2001,'v','2024-01-01 11:44'),(7,2004,'v','2024-01-01 10:00'),(8,2004,'v','2024-01-01 10:30'),(9,2004,'v','2024-01-01 10:45')""",("'YYYY-MM-DD HH24:MI:SS'","'%Y-%m-%d %H:%M:%S'"))
run('06_funnel.sql',"""create table users(user_id varchar,signup_date date); insert into users values('U001','2024-01-01'),('U002','2024-01-01'),('U003','2024-01-01'),('U004','2024-01-01');
create table events(event_id int,user_id varchar,event_type varchar,event_date date);
insert into events values(1,'U001','view','2024-01-02'),(2,'U001','view','2024-01-02'),(3,'U001','click','2024-01-02'),(4,'U001','click','2024-01-02'),(5,'U001','purchase','2024-01-02'),(6,'U002','view','2024-01-02'),(7,'U002','view','2024-01-02'),(8,'U002','view','2024-01-02'),(9,'U002','view','2024-01-02'),(10,'U002','view','2024-01-02'),(11,'U003','purchase','2024-01-02')""")
run('07_retention_cohorts.sql',"""create table transactions(user_id int,transaction_date date,amount int);
insert into transactions values(1,'2024-01-08',10),(1,'2024-01-20',10),(2,'2024-01-10',5),(3,'2024-01-15',5),(1,'2024-02-03',5),(1,'2024-03-01',5),(2,'2024-03-02',5),(4,'2024-02-01',5),(5,'2024-02-02',5),(4,'2024-03-05',5)""",("'YYYY-MM'","'%Y-%m'"))
run('08_top_n_per_group.sql',"""create table sales(sale_id int,region varchar,product_name varchar,revenue int,sale_date date);
insert into sales values(1,'North','Laptop',750,null),(2,'North','Laptop',750,null),(3,'North','Monitor',800,null),(4,'North','Tablet',800,null),(5,'North','Mouse',200,null)""")
run('09_pivot.sql',"""create table sales(sale_id int,product varchar,region varchar,amount decimal(10,2));
insert into sales values(1,'Apple','North',150),(2,'Apple','South',200),(3,'Banana','North',25),(4,'Banana','West',75),(5,'Orange','North',150),(6,'Orange','South',100),(7,'Orange','East',250)""")
emp="""create table employees(employee_id int,manager_id int,name varchar,salary int);
insert into employees values(101,null,'CEO',100000),(102,101,'Alice',80000),(103,101,'Bob',110000),(104,102,'Charlie',85000),(105,102,'Diana',70000)"""
run('10_self_join.sql',emp); run('11_recursive_hierarchy.sql',emp)
run('12_moving_average.sql',"""create table customer_visits(customer_id int,visit_date date,amount int);
insert into customer_visits values(1,'2024-01-01',50),(2,'2024-01-02',60),(3,'2024-01-03',70),(4,'2024-01-04',90),(5,'2024-01-05',85),(6,'2024-01-06',100),(7,'2024-01-07',95)""")
