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
import ChartCommon as C exposing (Candlestick, ChartInfo, ChartInfoJs, Chart)


mainUrl =
    "/maunaloa"


type alias Flags =
    { isWeekly : Bool
    }



{-
   main : Program Never Model Msg
   main =
       H.program
           { init = init
           , view = view
           , update = update
           , subscriptions = subscriptions
           }

-}


main : Program Flags Model Msg
main =
    H.programWithFlags
        { init = init
        , view = view
        , update = update
        , subscriptions = subscriptions
        }



-------------------- PORTS ---------------------


port drawCanvas : ChartInfoJs -> Cmd msg



-------------------- INIT ---------------------
{-
   init : ( Model, Cmd Msg )
   init =
       ( initModel, fetchTickers )
-}


init : Flags -> ( Model, Cmd Msg )
init flags =
    ( initModel flags, fetchTickers )



------------------- MODEL ---------------------


type alias Model =
    { tickers : Maybe SelectItems
    , selectedTicker : String
    , minDx : Date
    , maxDx : Date
    , chartInfo : Maybe ChartInfo
    , chartInfoWin : Maybe ChartInfoJs
    , dropItems : Int
    , takeItems : Int
    , chartWidth : Float
    , chartHeight : Float
    , chartHeight2 : Float
    , flags : Flags
    }


initModel : Flags -> Model
initModel flags =
    { tickers = Nothing
    , selectedTicker = "-1"
    , minDx = Date.fromTime 0
    , maxDx = Date.fromTime 0
    , chartInfo = Nothing
    , chartInfoWin = Nothing
    , dropItems = 0
    , takeItems = 90
    , chartWidth = 1300
    , chartHeight = 600
    , chartHeight2 = 300
    , flags = flags
    }



------------------- TYPES ---------------------
--


type Msg
    = TickersFetched (Result Http.Error SelectItems)
    | FetchCharts String
    | ChartsFetched (Result Http.Error ChartInfo)



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

        hs2 =
            toString model.chartHeight2

        stroke =
            "#023963"

        svgBaseLines =
            [ S.line [ SA.x1 "0", SA.y1 "0", SA.x2 "0", SA.y2 hs, SA.stroke stroke ] []
              --, S.line [ SA.x1 "0", SA.y1 hs, SA.x2 ws, SA.y2 hs, SA.stroke stroke ] []
              -- , S.line [ SA.x2 "0", SA.y1 "0", SA.x2 ws, SA.y2 "0", SA.stroke stroke ] []
            ]

        svgBaseLines2 =
            [ S.line [ SA.x1 "0", SA.y1 "0", SA.x2 "0", SA.y2 hs2, SA.stroke stroke ] []
              -- , S.line [ SA.x1 "0", SA.y1 hs2, SA.x2 ws, SA.y2 hs2, SA.stroke stroke ] []
            ]

        ( vruler, hruler, hruler2, vruler2 ) =
            case model.chartInfoWin of
                Nothing ->
                    ( [], [], [], [] )

                Just ci ->
                    ( [], [], [], [] )

        {-
           let
               vruler_ =
                   VR.lines w model.chartHeight 10 ci.chartLines

               hruler_ =
                   HR.lines w model.chartHeight model.minDx model.maxDx

               vruler2_ =
                   case ci.chartLines2 of
                       Nothing ->
                           []

                       Just cl2_ ->
                           VR.lines w model.chartHeight2 5 cl2_

               hruler2_ =
                   case ci.chartLines2 of
                       Nothing ->
                           []

                       Just cl2_ ->
                           HR.lines w model.chartHeight2 model.minDx model.maxDx
           in
               ( vruler_, hruler_, vruler2_, hruler2_ )
        -}
    in
        H.div [ A.class "container" ]
            [ H.div [ A.class "row" ]
                [ -- checkbox ToggleWeekly "Weekly"
                  makeSelect "Tickers: " FetchCharts model.tickers model.selectedTicker
                ]
            , H.div [ A.style [ ( "position", "absolute" ), ( "top", "300px" ), ( "left", "200px" ) ] ]
                [ S.svg [ SA.width (ws ++ "px"), SA.height (hs ++ "px") ]
                    (List.append
                        svgBaseLines
                        (List.append hruler vruler)
                    )
                ]
            , H.div [ A.style [ ( "position", "absolute" ), ( "top", "950px" ), ( "left", "200px" ) ] ]
                [ S.svg [ SA.width (ws ++ "px"), SA.height (hs2 ++ "px") ]
                    (List.append svgBaseLines2
                        (List.append hruler2 vruler2)
                    )
                ]
            ]



------------------- UPDATE --------------------


scaledCandlestick : (Float -> Float) -> Candlestick -> Candlestick
scaledCandlestick vruler cndl =
    let
        opn =
            vruler cndl.o

        hi =
            vruler cndl.h

        lo =
            vruler cndl.l

        cls =
            vruler cndl.c
    in
        Candlestick opn hi lo cls



{-
   chartWindowLines : Model -> List (List Float) -> Maybe (List Candlestick) -> Float -> ( ChartLines, Maybe (List Candlestick) )
   chartWindowLines model lines candlesticks chartHeight =
       let
           valueFn : List a -> List a
           valueFn vals =
               List.take model.takeItems <| List.drop model.dropItems vals

           lines_ =
               List.map valueFn lines

           cndl_window =
               case candlesticks of
                   Nothing ->
                       Nothing

                   Just candlesticks_ ->
                       Just (valueFn candlesticks_)

           valueRange =
               case cndl_window of
                   Nothing ->
                       List.map VR.minMax lines_ |> M.minMaxTuples

                   Just candlesticks_ ->
                       VR.minMaxCndl candlesticks_ :: (List.map VR.minMax lines_) |> M.minMaxTuples

           vr =
               VR.vruler valueRange chartHeight

           cndl_ =
               case cndl_window of
                   Nothing ->
                       Nothing

                   Just cs ->
                       let
                           vr_cndl =
                               scaledCandlestick vr

                           my_cndls =
                               valueFn cs
                       in
                           Just (List.map vr_cndl my_cndls)
       in
           ( ChartLines
               (TUP.first valueRange)
               (TUP.second valueRange)
               (List.map (List.map vr) lines_)
           , cndl_
           )
-}
{-
   chartWindow : ChartInfo -> Model -> ( ChartInfoJs, Date, Date )
   chartWindow ci model =
       let
           xAxis_ =
               List.take model.takeItems <| List.drop model.dropItems ci.xAxis

           ( minDx_, maxDx_ ) =
               HR.dateRangeOf ci.minDx xAxis_

           hr =
               HR.hruler minDx_ maxDx_ xAxis_ model.chartWidth

           ( lines1_, cndl_ ) =
               chartWindowLines model ci.lines ci.candlesticks model.chartHeight

           lines2_ =
               case ci.lines2 of
                   Nothing ->
                       Nothing

                   Just lx2 ->
                       let
                           ( lx2_, _ ) =
                               chartWindowLines model lx2 Nothing model.chartHeight2
                       in
                           Just lx2_

           strokes =
               [ "#000000", "#ff0000", "#aa00ff" ]
       in
           ( ChartInfoJs
               (List.map hr xAxis_)
               lines1_
               cndl_
               lines2_
               strokes
           , minDx_
           , maxDx_
           )
-}


slice : Model -> List a -> List a
slice model vals =
    List.take model.takeItems <| List.drop model.dropItems vals


chartValueRange : Chart -> ( Float, Float )
chartValueRange c = (2,3) 
{-
    let
        lr =
            case c.lines of 
                Nothing -> (
            List.map VR.minMax lines_ |> M.minMaxTuples
            

            case c.candlesticks of
                Nothing ->
                    List.map VR.minMax lines_ |> M.minMaxTuples

                Just candlesticks_ ->
                    VR.minMaxCndl candlesticks_ :: (List.map VR.minMax lines_) |> M.minMaxTuples
-}

chartWindow : Model -> Chart -> Chart
chartWindow model c =
    let
        sliceFn =
            slice model

        lines_ =
            case c.lines of
                Nothing ->
                    Nothing

                Just l ->
                    Just (List.map sliceFn l)

        bars_ =
            case c.bars of
                Nothing ->
                    Nothing

                Just b ->
                    Just (List.map sliceFn b)

        cndl_ =
            case c.candlesticks of
                Nothing ->
                    Nothing

                Just cndl ->
                    Just (sliceFn cndl)

        valueRange = chartValueRange c


        vr =
            VR.vruler valueRange 100 -- chartHeight

    in
        Chart lines_ bars_ cndl_ 


chartInfoWindow : ChartInfo -> Model -> ( ChartInfoJs, Date, Date )
chartInfoWindow ci model =
    let
        xAxis_ =
            slice model ci.xAxis

        ( minDx_, maxDx_ ) =
            HR.dateRangeOf ci.minDx xAxis_

        hr =
            HR.hruler minDx_ maxDx_ xAxis_ model.chartWidth

        strokes =
            [ "#000000", "#ff0000", "#aa00ff" ]

        chw =
            chartWindow model ci.chart
    in
        ( ChartInfoJs
            (List.map hr xAxis_)
            strokes
        , minDx_
        , maxDx_
        )


httpErr2str : Http.Error -> String
httpErr2str err =
    case err of
        Http.Timeout ->
            "Timeout"

        Http.NetworkError ->
            "NetworkError"

        Http.BadUrl s ->
            "BadUrl: " ++ s

        Http.BadStatus r ->
            "BadStatus: "

        Http.BadPayload s r ->
            "BadPayload: " ++ s


update msg model =
    case msg of
        -- ToggleWeekly ->
        -- ( { model | isWeekly = not model.isWeekly }, Cmd.none )
        TickersFetched (Ok s) ->
            ( { model
                | tickers = Just s
              }
            , Cmd.none
            )

        TickersFetched (Err s) ->
            Debug.log ("TickersFetched Error: " ++ (httpErr2str s)) ( model, Cmd.none )

        FetchCharts s ->
            ( { model | selectedTicker = s }, fetchCharts s model )

        ChartsFetched (Ok s) ->
            Debug.log (toString s)
                ( model, Cmd.none )

        {-
           let
               ( ciWin, minDx, maxDx ) =
                   chartWindow s model
           in
               ( { model
                   | chartInfo = Just s
                   , chartInfoWin = Just ciWin
                   , minDx = minDx
                   , maxDx = maxDx
                 }
               , drawCanvas ciWin
               )
        -}
        ChartsFetched (Err s) ->
            Debug.log ("ChartsFetched Error: " ++ (httpErr2str s))
                ( model, Cmd.none )



------------------ COMMANDS -------------------


fetchTickers : Cmd Msg
fetchTickers =
    let
        url =
            mainUrl ++ "/tickers"
    in
        Http.send TickersFetched <|
            Http.get url comboBoxItemListDecoder


candlestickDecoder : Json.Decoder Candlestick
candlestickDecoder =
    Json.map4 Candlestick
        (Json.field "o" Json.float)
        (Json.field "h" Json.float)
        (Json.field "l" Json.float)
        (Json.field "c" Json.float)


chartDecoder : Float -> Json.Decoder Chart
chartDecoder chartHeight =
    let
        lines =
            (Json.field "lines" (Json.maybe (Json.list (Json.list Json.float))))

        bars =
            (Json.field "bars" (Json.maybe (Json.list (Json.list Json.float))))

        candlesticks =
            (Json.field "cndl" (Json.maybe (Json.list candlestickDecoder)))
    in
        Json.map3 Chart lines bars candlesticks 

{-
    JP.decode Chart
        |> JP.required "lines" (Json.nullable (Json.list Json.float))
        |> JP.required "bars" (Json.nullable (Json.list Json.float))
        |> JP.required "cndl" (Json.nullable (Json.list candlestickDecoder))
        |> JP.hardcoded chartHeight 
-}
    

fetchCharts : String -> Model -> Cmd Msg
fetchCharts ticker model =
    let
        myDecoder =
            JP.decode ChartInfo
                |> JP.required "min-dx" stringToDateDecoder
                |> JP.required "x-axis" (Json.list Json.float)
                |> JP.required "chart" (chartDecoder 100)

        -- |> JP.hardcoded Nothing
        url =
            if model.flags.isWeekly == True then
                mainUrl ++ "/tickerweek?oid=" ++ ticker
            else
                mainUrl ++ "/ticker?oid=" ++ ticker
    in
        Http.send ChartsFetched <| Http.get url myDecoder



---------------- SUBSCRIPTIONS ----------------


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.none
