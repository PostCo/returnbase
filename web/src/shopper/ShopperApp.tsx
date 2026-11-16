import { useEffect, useState } from "react";
import { RequestReturnPage } from "./RequestReturnPage";
import { StatusPage } from "./StatusPage";
import { Shop, shopperApi } from "./api";
import { themeFor, themeVars } from "./themes";
import "./shopper.css";

export function ShopperApp() {
  const isStatus = window.location.pathname.startsWith("/shopper/status");
  const [shops, setShops] = useState<Shop[]>([]);
  const [shopId, setShopId] = useState<number>(Number(new URLSearchParams(window.location.search).get("shop")) || 0);

  useEffect(() => {
    shopperApi.shops().then(({ shops }) => {
      setShops(shops);
      setShopId((current) => current || shops[0]?.id || 0);
    });
  }, []);

  const shop = shops.find((s) => s.id === shopId);

  return (
    <div className="shop" style={themeVars(themeFor(shop?.name))}>
      <header className="shop-head">
        <h1 className="shop-logo">
          <i aria-hidden="true">{shop?.name.charAt(0)}</i>
          {shop?.name ?? "Returns"}
        </h1>
      </header>
      <main className="shop-wrap">
        <div className="shop-kicker">Returns</div>
        {isStatus ? <StatusPage /> : <RequestReturnPage shops={shops} shopId={shopId} onShopChange={setShopId} />}
        <p className="shop-foot">Returns powered by Returnbase</p>
      </main>
    </div>
  );
}

