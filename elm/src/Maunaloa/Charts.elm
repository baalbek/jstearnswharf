port module Maunaloa.Charts exposing (..)

import Date exposing (Date)
import Http
import Html as H
import Html.Attributes as A
import Svg as S
import Svg.Attributes as SA
import Json.Decode as Json
import Json.Decode.Pipeline as JP
import Common.Miscellaneous as M
import Common.DateUtil as DU
import ChartRuler.HRuler as HR
import ChartRuler.VRuler as VR
import Tuple as TUP


-- import Common.ModalDialog exposing (ModalDialog, dlgOpen, dlgClose, makeOpenDlgButton, modalDialog)

import Common.Miscellaneous exposing (checkbox, makeLabel, onChange, stringToDateDecoder)
import Common.ComboBox
    exposing
        ( ComboBoxItem
        , SelectItems
        , comboBoxItemListDecoder
        , makeSelect
        )
import ChartRuler.VRuler as VR
import ChartCommon as C exposing (ChartValues, Candlestick, ChartInfo, chartInfo1, chartInfo2)


mainUrl =
    "/maunaloa"


main : Program Never Model Msg
main =
    H.program
        { init = init
        , view = view
        , update = update
        , subscriptions = subscriptions
        }



-------------------- PORTS ---------------------


port drawCanvas : ( List (List Float), List Float, List String ) -> Cmd msg



-------------------- INIT ---------------------


init : ( Model, Cmd Msg )
init =
    ( initModel, fetchTickers )



------------------- MODEL ---------------------
{-
   , spots : Maybe (List Float)
   , candlesticks : Maybe (List Candlestick)
-}


type alias Model =
    { tickers : Maybe SelectItems
    , selectedTicker : String
    , chartInfo : Maybe ChartInfo
    , chartInfoWin : Maybe ChartInfo
    , dropItems : Int
    , takeItems : Int
    , chartWidth : Float
    , chartHeight : Float
    , isCandlesticks : Bool
    }


initModel : Model
initModel =
    { tickers = Nothing
    , selectedTicker = "-1"
    , chartInfo = Nothing
    , chartInfoWin = Nothing
    , dropItems = 0
    , takeItems = 900
    , chartWidth = 1300
    , chartHeight = 600
    , isCandlesticks = False
    }



------------------- TYPES ---------------------
--


type Msg
    = TickersFetched (Result Http.Error SelectItems)
    | FetchCharts String
    | ChartsFetched (Result Http.Error ChartInfo)
    | ToggleCandlestics



-------------------- VIEW ---------------------


view : Model -> H.Html Msg
view model =
    let
        w =
            model.chartWidth + 100

        ws =
            toString w

        hs =
            toString model.chartHeight

        stroke =
            "#023963"

        svgBaseLines =
            [ S.line [ SA.x1 "0", SA.y1 "0", SA.x2 "0", SA.y2 hs, SA.stroke stroke ] []
              --, S.line [ SA.x1 "0", SA.y1 hs, SA.x2 ws, SA.y2 hs, SA.stroke stroke ] []
              -- , S.line [ SA.x2 "0", SA.y1 "0", SA.x2 ws, SA.y2 "0", SA.stroke stroke ] []
            ]

        hruler =
            case model.chartInfoWin of
                Nothing ->
                    []

                Just ci ->
                    []

        vruler =
            case model.chartInfoWin of
                Nothing ->
                    []

                Just ci ->
                    VR.lines w model.chartHeight ci
    in
        H.div [ A.class "container" ]
            [ H.div [ A.class "row" ]
                [ checkbox ToggleCandlestics "Candlesticks"
                , makeSelect "Tickers: " FetchCharts model.tickers model.selectedTicker
                ]
            , H.div [ A.style [ ( "position", "absolute" ), ( "top", "200px" ), ( "left", "200px" ) ] ]
                [ S.svg [ SA.width (ws ++ "px"), SA.height (hs ++ "px") ]
                    (List.append
                        svgBaseLines
                        (List.append hruler vruler)
                    )
                ]
            ]



------------------- UPDATE --------------------


chartWindow : ChartInfo -> Model -> ChartInfo
chartWindow cix model =
    case cix of
        C.EmptyChartInfo ->
            C.EmptyChartInfo

        C.ChartInfo2 ci ->
            let
                xAxis_ =
                    List.take model.takeItems <| List.drop model.dropItems ci.base.xAxis

                ( minDx_, maxDx_ ) =
                    HR.dateRangeOf ci.base.minDx xAxis_

                hr =
                    HR.hruler minDx_ maxDx_ xAxis_ model.chartWidth

                valueRange =
                    VR.minMaxCndl ci.cndl

                vr =
                    VR.vruler valueRange model.chartHeight

                myBase =
                    C.ChartInfoBase minDx_ maxDx_ (TUP.first valueRange) (TUP.second valueRange) (List.map hr xAxis_)
            in
                C.EmptyChartInfo

        C.ChartInfo1 ci ->
            let
                valueFn : ChartValues -> ChartValues
                valueFn vals =
                    case vals of
                        Nothing ->
                            Nothing

                        Just s ->
                            Just <| List.take model.takeItems <| List.drop model.dropItems s

                xAxis_ =
                    List.take model.takeItems <| List.drop model.dropItems ci.base.xAxis

                ( minDx_, maxDx_ ) =
                    HR.dateRangeOf ci.base.minDx xAxis_

                hr =
                    HR.hruler minDx_ maxDx_ xAxis_ model.chartWidth

                spots_ =
                    valueFn ci.spots

                itrend20_ =
                    valueFn ci.itrend20

                graphs =
                    [ spots_, itrend20_ ]

                valueRange =
                    List.map VR.minMax graphs |> M.minMaxTuples

                vr =
                    VR.vruler valueRange model.chartHeight

                myBase =
                    C.ChartInfoBase minDx_ maxDx_ (TUP.first valueRange) (TUP.second valueRange) (List.map hr xAxis_)
            in
                C.ChartInfo1
                    { base = myBase
                    , spots = M.maybeMap vr spots_
                    , itrend20 = M.maybeMap vr itrend20_
                    }


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        ToggleCandlestics ->
            ( { model | isCandlesticks = not model.isCandlesticks }, Cmd.none )

        TickersFetched (Ok s) ->
            Debug.log "TickersFetched"
                ( { model
                    | tickers = Just s
                  }
                , Cmd.none
                )

        TickersFetched (Err s) ->
            Debug.log "TickersFetched Error" ( model, Cmd.none )

        FetchCharts s ->
            let
                fetchCharts_ =
                    if model.isCandlesticks == True then
                        fetchCharts2
                    else
                        fetchCharts
            in
                Debug.log "FetchCharts"
                    ( { model | selectedTicker = s }, fetchCharts_ s )

        ChartsFetched (Ok s) ->
            let
                ciWin =
                    chartWindow s model
            in
                Debug.log "ChartsFetched "
                    ( { model | chartInfo = Just s, chartInfoWin = Just ciWin }, drawChartInfo ciWin )

        ChartsFetched (Err _) ->
            Debug.log "ChartsFetched err"
                ( model, Cmd.none )


drawChartInfo : ChartInfo -> Cmd Msg
drawChartInfo cix =
    case cix of
        C.EmptyChartInfo ->
            Cmd.none

        C.ChartInfo2 ci ->
            Cmd.none

        C.ChartInfo1 ci ->
            let
                spots =
                    Maybe.withDefault [] ci.spots

                itrend20 =
                    Maybe.withDefault [] ci.itrend20
            in
                Debug.log (toString ci)
                    drawCanvas
                    ( [ spots, itrend20 ], ci.base.xAxis, [ "#000000", "#ff0000" ] )



------------------ COMMANDS -------------------


fetchTickers : Cmd Msg
fetchTickers =
    let
        url =
            mainUrl ++ "/tickers"
    in
        Http.send TickersFetched <|
            Http.get url comboBoxItemListDecoder


fetchCharts : String -> Cmd Msg
fetchCharts ticker =
    let
        myDecoder =
            JP.decode chartInfo1
                |> JP.required "min-dx" stringToDateDecoder
                |> JP.required "max-dx" stringToDateDecoder
                |> JP.optional "min-val" Json.float 0.0
                |> JP.optional "max-val" Json.float 0.0
                |> JP.required "x-axis" (Json.list Json.float)
                |> JP.required "spots" (Json.nullable (Json.list Json.float))
                |> JP.required "itrend-20" (Json.nullable (Json.list Json.float))

        url =
            mainUrl ++ "/ticker?oid=" ++ ticker
    in
        Http.send ChartsFetched <| Http.get url myDecoder


fetchCharts2 : String -> Cmd Msg
fetchCharts2 ticker =
    let
        candlestickDecoder =
            Json.map4 Candlestick
                (Json.field "o" Json.float)
                (Json.field "h" Json.float)
                (Json.field "l" Json.float)
                (Json.field "c" Json.float)

        myDecoder =
            JP.decode chartInfo2
                |> JP.required "min-dx" stringToDateDecoder
                |> JP.required "max-dx" stringToDateDecoder
                |> JP.optional "min-val" Json.float 0.0
                |> JP.optional "max-val" Json.float 0.0
                |> JP.required "x-axis" (Json.list Json.float)
                |> JP.required "cndl" (Json.list candlestickDecoder)

        url =
            mainUrl ++ "/tickercndl?oid=" ++ ticker
    in
        Http.send ChartsFetched <| Http.get url myDecoder



---------------- SUBSCRIPTIONS ----------------


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.none
