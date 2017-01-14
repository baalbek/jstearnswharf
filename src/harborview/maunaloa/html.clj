(ns harborview.maunaloa.html
  (:import
    [java.sql Date]
    [java.time LocalDate]
    [java.time.temporal ChronoUnit]
    [vega.filters.ehlers Itrend CyberCycle])
  (:use
    [compojure.core :only (GET POST defroutes)])
  (:require
    [clj-json.core :as json]
    [selmer.parser :as P]
    [harborview.maunaloa.dbx :as DBX]
    [harborview.service.htmlutils :as U]))

(def calc-itrend (Itrend.))

(def calc-cc (CyberCycle.))

(defn create-freqs [f data-values freqs]
  (map #(f data-values %) freqs))

(defn double->decimal [v]
  (/ (Math/round (* v 10)) 10.0))

(defn vruler [h min-val max-val]
  (let [pix-pr-v (/ h (- max-val min-val))]
    (fn [v]
      (let [diff (- max-val v)]
        (double->decimal (double (* pix-pr-v diff)))))))

(defn hruler [w min-dx max-dx]
  (let [diff-days
        (fn [d1 d2]
          (.between ChronoUnit/DAYS d1 d2))
        days (diff-days min-dx max-dx)
        pix-pr-h (/ w days)]
    (fn [dx]
      (let [cur-diff (diff-days min-dx dx)]
        (double->decimal (double (* pix-pr-h cur-diff)))))))

(defn ld->str [v]
  (let [y (.getYear v)
        m (.getMonthValue v)
        d (.getDayOfMonth v)]
    (str y "-" m "-" d)))


(comment ticker-chart [oid w h]
  (let [min-dx (LocalDate/of 2014 7 1)
        spot-objs (DBX/fetch-prices (U/rs oid) (Date/valueOf min-dx))
        spots (map #(.getCls %) spot-objs)
        dx (map #(.toLocalDate (.getDx %)) spot-objs)
        max-dx (last dx)
        min-val (apply min spots)
        max-val (apply max spots)
        hr (hruler w min-dx max-dx)]
    dx))


(defn ticker-chart [oid w h]
  (let [min-dx (LocalDate/of 2014 1 1)
        spot-objs (DBX/fetch-prices (U/rs oid) (Date/valueOf min-dx))
        spots (map #(.getCls %) spot-objs)
        itrend-20 (calc-itrend spots 20)
        dx (map #(.toLocalDate (.getDx %)) spot-objs)
        max-dx (last dx)
        ys (concat spots itrend-20)
        min-val (apply min ys)
        max-val (apply max ys)
        vr (vruler h min-val max-val)
        hr (hruler w min-dx max-dx)]
    (U/json-response
      {:spots (map vr spots)
       :itrend-20 (map vr itrend-20)
       ;:candlesticks [
       ;               {:o 3, :h 4, :l 1, :c 2.5}
       ;               {:o 3, :h 4, :l 1, :c 2.5}
       ;               {:o 3, :h 4, :l 1, :c 2.5}
       ;               {:o 3, :h 4, :l 1, :c 2.5}
       ;               {:o 3, :h 4, :l 1, :c 2.5}
       ;               {:o 3, :h 4, :l 1, :c 2.5}
       ;               {:o 3, :h 4, :l 1, :c 2.5}
       ;               {:o 3, :h 4, :l 1, :c 2.5}
       ;               {:o 3, :h 4, :l 1, :c 2.5}]

       :x-axis (map hr dx) ; [0 50 100 150 200]
       :min-val min-val
       :max-val max-val
       :min-dx (ld->str min-dx)
       :max-dx (ld->str max-dx)})))


(defn tickers []
  (U/json-response
    ;(map (fn [s] {"t" (.getTicker s) "v" (.getOid s)})
    ;  (DBX/fetch-tickers))))
    (map (fn [x] (let [[v t] x] {"t" t "v" v}))
      [["2" "STL"] ["1" "NHY"] ["3" "YAR"]])))

(defn init []
  (P/render-file "templates/maunaloa/charts.html" {}))


(defroutes my-routes
  (GET "/" request (init))
  (GET "/tickers" request (tickers))
  (GET "/ticker" [oid] (ticker-chart (U/rs oid) 1200 600)))
