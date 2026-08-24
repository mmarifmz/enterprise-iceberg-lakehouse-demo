from scripts.download_adventureworks import BASE_URL, FILES


def test_downloader_uses_official_microsoft_repository() -> None:
    assert BASE_URL.startswith("https://raw.githubusercontent.com/microsoft/sql-server-samples/")
    assert "FactInternetSales.csv" in FILES
    assert len(FILES) >= 3

