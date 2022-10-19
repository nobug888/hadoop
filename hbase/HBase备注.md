## 1.如何理解HBase的K-V存储

如果粒度是一行:

​		K ：  行键(rowkey)

​       V   ：  一行



如果粒度是一个单元格(cell)：

​		K ：   rowkey-- column family -- column qulifaiy -- timestamp

​       V :  value（格子中的值）



## 2.为什么HBase是一个Versiond数据库?

为什么一列中支持存储多个vesion？

HBase依赖HDFS存数据！

HDFS特性： 不支持随机写，只支持追加写!



HBase如果希望修改一个列的值，原理是追加一个新的值，只返回追加的新的值，让客户端误认为已经修改完成！

老的值会在后期重写文件期间删除!



## 3.概念

库：  namespace。 安装好后，自带两个库 hbase（自用） ,default（表默认在这个库，给用户用）

表:    table 。 建表时，只需要指定表有几个列族即可!

列族：  在建表时指定，一个列族(store)中可以定义无限列，所有的列的数据都会放入同一个文件(StoreFile)

​				官方不建议建多，一般只建一个

列： 在插入数据时，由客户端指定。 列的名字和数量无限制，唯一需要指定的是列必须依附于列族

​				格式:  列族(表定义号的):列名

行：  有一个rowkey（行键，行的唯一标识）

区域: region 。 一张表会划分为 N个region，每个region有N行。

​				一个region中的所有行，会使用rowkey 字段排序，方便检索

​				一个region 的读写请求会交给一个regionserver（进程）处理！

​				region过大，会切分。

​				如果当前region所在的regionserver繁忙，处于负载均衡的目的，会将region重新分配其他的regionserver



timestamp: 每条数据写入，都必带ts。 查询时，可以指定查下指定ts的数据，也可以不指定(返回ts最大的，最新的)

cell:  单元格，一列中，可以有多个版本的不同数据，每个版本都称为一个cell

​				

## 4.数据和元数据

hbase的数据:  表中的数据，在hdfs存储

hbase的元数据:   有哪些表，哪些库，哪些regionserver在zk存储





## 5.列族的描述

```
{NAME => 'f1', VERSIONS => '3', EVICT_BLOCKS_ON_CLOSE => 'false', NEW_VERSION_BEHAVIOR => 'false', KEEP_DELETED_CELLS => 'FALSE', CACHE_DATA_ON_WRITE 
=> 'false', DATA_BLOCK_ENCODING => 'NONE', TTL => 'FOREVER', MIN_VERSIONS => '0', REPLICATION_SCOPE => '0', BLOOMFILTER => 'ROW', CACHE_INDEX_ON_WRITE
 => 'false', IN_MEMORY => 'false', CACHE_BLOOMS_ON_WRITE => 'false', PREFETCH_BLOCKS_ON_OPEN => 'false', COMPRESSION => 'NONE', BLOCKCACHE => 'true', 
BLOCKSIZE => '65536'}
```



## 6.HDFS上数据的存储

数据存储在 HDFS  的 /hbase/data中

按照库和表分类存放。



库： 对应HDFS上 data下的一个子目录

表：  对应HDFS上data下库的目录中的子目录

region: 对应表中的一个子目录

列族(Store)： 是在region下的子目录

表中的数据:  一个列族中所有列的数据会优先存储在内存中，达到一定条件，再刷写到hdfs。

​						刷写后的每个文件称为 StoreFile（HFile）。 列式存储！

​			StoreFile:  理论上的名字

​			HFile:  作者在写代码的时候起 的类名



## 7.数据的存储

```
hbase(main):045:0> scan 't1', {RAW => true, VERSIONS => 10}
ROW                                    COLUMN+CELL                                                                                                    
 a1                                    column=f1:age, timestamp=1652597081689, type=DeleteColumn                                                      
 a1                                    column=f1:age, timestamp=1652596737248, type=Delete                                                            
 a1                                    column=f1:age, timestamp=1652596737248, value=25                                                               
 a1                                    column=f1:age, timestamp=1652596624048, value=20                                                               
 a1                                    column=f1:gender, timestamp=1652596640641, value=male                                                          
 a1                                    column=f1:name, timestamp=1652596588289, value=jack                                                            
 a2                                    column=f1:age, timestamp=1652596659498, value=30                                                               
 a2                                    column=f1:gender, timestamp=1652596665617, value=male                                                          
 a2                                    column=f1:name, timestamp=1652596654321, value=tom   
 
 
 ---以上数据是在内存中存储
 
 -- flush 't1'
 
 /hbase/data/default/t1/a1b2eb73069111330226640c5ffc0709/f1/83bf9a7146ce41c9be0fbf1b7541ea70
 
 -- scan 't1' , {RAW => true, VERSIONS => 10}
 ROW                                    COLUMN+CELL                                                                                                    
 a1                                    column=f1:age, timestamp=1652597081689, type=DeleteColumn                                                      
 a1                                    column=f1:age, timestamp=1652596737248, type=Delete                                                            
 a1                                    column=f1:gender, timestamp=1652596640641, value=male                                                          
 a1                                    column=f1:name, timestamp=1652596588289, value=jack                                                            
 a2                                    column=f1:age, timestamp=1652596659498, value=30                                                               
 a2                                    column=f1:gender, timestamp=1652596665617, value=male                                                          
 a2                                    column=f1:name, timestamp=1652596654321, value=tom 
 
```

①flush不会删除delete类型的cell

②flush 会把 ts  小于 delete类型的cell ts的cell删除(不刷写到HFile)

```
#打印hfile中的K-V对
hbase hfile -p HFile的路径
```

③在刷写时，参考列族的versions属性，每个storefile（HfILE）都保留最多versions数量的cell.



## 8.RegionServer的架构

一个RegionServer负责处理N个Region的读写请求！

一个Region只能交个一个RegionServer处理!

一个RegionServer有一个HLog对象，负责基于 WAL(预写日志)机制，记录客户端的写操作。

WAL：  客户端在执行写操作时，会在将数据加入到memstore(内存存储)之前，提前在日志中记录写操作命令！

​			以便由于RS的故障造成memstore中未刷写的数据丢失时，可以及时读取HLog File中的命令恢复丢失的数据!



BlockCache: 用于缓存已经读取的StofeFile中的block 块。

​						当需要扫描某个StoreFile读取某个block块时，会在Blockcache中优先寻找，找不到再读取StoreFile，会将读取的block存入blockcache，以供后续使用。

​			一个Regionserver（64G）维护一个Blockcache对象，占RS进程 堆内存的 30%-40%



一个Region中会有多个列族(Store)，每个列族的数据都份两部分存储:

​			内存存储: memstore

​			文件存储:  在HDFS上有若干个 HFile(storefile)



## 9.memstore中的数据一定比HFile新吗?

在使用Regionserver向hbase写入数据时，是的!



一种跳过RegionServer向HBase写数据的方法: BulkLoad （批量导入）。 直接将源数据用HFile的格式生成，上传到HDFS的目录!



## 10.写流程

客户端发送:

```
put 't1','a1','cf1:name','jack'
```

第一部分：

​				**找到 t1表的a1行所在region的regionserver!**



①可以通过扫描 zookeeper中 /hbase/meta-region-server 节点，得知hbase-meta表所在的regionserver！向regionserver发请求，读取hbase:meta表



②客户端需要扫描 hbase:meta 表读取每个region 的元数据信息，有startkey，endkey，通过对扫描的rowkey的比较，可以判断这行数据是否在这个region中，如果在，通过这个region的column=info:server列获取当前region对应的regionserver!



第二部分： **向regionserver发送写请求**



③regionserver收到put请求后，根据put的region找到 region下的列族，先将写命令基于WAL机制写到 HLog中

④将数据写入列族的memstore对象中，写成功，返回客户端消息成功!



## 11.读流程

第一部分：

​				**找到 t1表的a1行所在region的regionserver!**



①可以通过扫描 zookeeper中 /hbase/meta-region-server 节点，得知hbase-meta表所在的regionserver！向regionserver发请求，读取hbase:meta表



②客户端需要扫描 hbase:meta 表读取每个region 的元数据信息，有startkey，endkey，通过对扫描的rowkey的比较，可以判断这行数据是否在这个region中，如果在，通过这个region的column=info:server列获取当前region对应的regionserver!



第二部分:

​					向regionserver发送读请求

```
get '表名',rowkey ： 读一行

scan '表名',{SK,EK}: 读N行。 有可能跨region读数据
		表有可能有多个列族。
		表的region下会有多个列族。
		
		


```



读的数据，通过meta表判断后，向指定的regionserver发请求。

③有几个region，regionserver就会初始化几个 RegionScaner。



④每个Region下有N个列族(Store)，RegionScanner会初始化N个StoreScanner



⑤每个StoreScanner负责扫描当前列族的数据，会初始化一个MemstoreScanner（扫描Memstore,跳表技术）

​			当前Store下有几个 StoreFile，就初始化几个 StoreFileScanner。



⑥StoreFileScanner扫描某个StoreFile文件时，会先加载文件的元数据(未读取文件中的数据块)，获取布隆过滤器的信息。

​		通过布隆过滤器可以判断当前要扫描的 数据是否一定不在这个文件或 可能在这个文件。

​		如果判断不在这个文件，此时这个StoreFileScanner自动销毁。

​		否则，如果可能在，会继续通过HFile的索引信息，检索当前数据在哪个block（64K）



⑦当找到数据所在的blockId后，此时会继续判断此block是否已经缓存在了BlockCache中，如果有，放弃读文件，

​		选择读取BlockCache，节省磁盘IO。

​		如果没有，只能读文件，会把读后的Block，缓存在BlockCache



⑧将MemstoreScanner读取的value 和 StoreFileScanner读取的value ，在BlockCache中读取的Value进行ts的比对，

​		返回客户端指定ts的value。

​			如果客户端未指定ts，返回最大ts的value!



## 12.Compact

频繁地刷写文件，会造成小文件过多!

刷写后，每个Storefile保存 Versions个Cell，会造成大量已经无效过时的数据已经在HFile中，占用磁盘空间!

刷写时，delelte类型的cell 和 deleteColumn类型的Cell 已经刷写到文件中，没有必要保存。



## 13.Phoenix的使用

```
CREATE TABLE IF NOT EXISTS student(
id VARCHAR primary key,
name VARCHAR,
addr VARCHAR)
COLUMN_ENCODED_BYTES = 0;

指定主键，主键作为rowkey，默认列族是0，所有的小写都会转为大写
```

upsert:  增|改，通过id判断操作类型，id存在就更新，否则就插入

delete:

select:



自己指定列族:

```
CREATE TABLE IF NOT EXISTS student(
id VARCHAR primary key,
f1.name VARCHAR,
f1.addr VARCHAR)
COLUMN_ENCODED_BYTES = 0;
```



字段小写:

```
CREATE TABLE IF NOT EXISTS "student1"(
"id" VARCHAR primary key,
"f1"."name" VARCHAR,
"f1"."addr" VARCHAR)
COLUMN_ENCODED_BYTES = 0;
```

