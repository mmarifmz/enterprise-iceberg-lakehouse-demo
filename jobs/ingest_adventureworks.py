"""Load Microsoft AdventureWorksDW Internet Sales CSV into an Iceberg table."""

from __future__ import annotations

import os
import tempfile
import urllib.request
from pathlib import Path

from pyspark.sql import SparkSession

SOURCE = (
    "https://raw.githubusercontent.com/microsoft/sql-server-samples/master/"
    "samples/databases/adventure-works/data-warehouse-install-script/FactInternetSales.csv"
)


def build_spark() -> SparkSession:
    rest_uri = os.environ.get("ICEBERG_REST_URI", "http://iceberg-rest:8181")
    s3_endpoint = os.environ.get("S3_ENDPOINT", "http://minio:9000")
    return (
        SparkSession.builder.appName("adventureworks-iceberg-ingestion")
        .config("spark.sql.extensions", "org.apache.iceberg.spark.extensions.IcebergSparkSessionExtensions")
        .config("spark.sql.catalog.demo", "org.apache.iceberg.spark.SparkCatalog")
        .config("spark.sql.catalog.demo.type", "rest")
        .config("spark.sql.catalog.demo.uri", rest_uri)
        .config("spark.sql.catalog.demo.warehouse", "s3://warehouse/")
        .config("spark.sql.catalog.demo.io-impl", "org.apache.iceberg.aws.s3.S3FileIO")
        .config("spark.sql.catalog.demo.s3.endpoint", s3_endpoint)
        .config("spark.sql.catalog.demo.s3.path-style-access", "true")
        .getOrCreate()
    )


def main() -> None:
    spark = build_spark()
    spark.sql("CREATE NAMESPACE IF NOT EXISTS demo.demo")
    with tempfile.TemporaryDirectory() as temp_dir:
        csv_path = Path(temp_dir) / "FactInternetSales.csv"
        request = urllib.request.Request(SOURCE, headers={"User-Agent": "lakehouse-demo"})
        with urllib.request.urlopen(request, timeout=180) as response:
            csv_path.write_bytes(response.read())
        frame = spark.read.option("header", True).option("inferSchema", True).csv(str(csv_path))
        row_count = frame.count()
        frame.writeTo("demo.demo.fact_internet_sales").using("iceberg").createOrReplace()
    print(f"loaded {row_count} AdventureWorks Internet Sales rows")
    spark.stop()



if __name__ == "__main__":
    main()
