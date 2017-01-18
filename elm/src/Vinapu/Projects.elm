module Vinapu.Projects exposing (..)

import Dict exposing (Dict)
import Http
import Html as H
import Html.Attributes as A
import Html.Events as E
import Debug
import Json.Encode as JE
import Json.Decode as Json exposing (field)
import VirtualDom as VD
import Task
import String
import Common.Miscellaneous as CM exposing (makeLabel, makeInput, onChange, makeFGRInput)
import Common.ModalDialog exposing (ModalDialog, dlgOpen, dlgClose, makeOpenDlgButton, modalDialog)
import Common.ComboBox
    exposing
        ( ComboBoxItem
        , SelectItems
        , comboBoxItemDecoder
        , comboBoxItemListDecoder
        , makeSelectOption
        , emptySelectOption
        , makeSelect
        , makeSimpleSelect
        , updateComboBoxItems
        , makeFGRSelect
        )


main : Program Never Model Msg
main =
    H.program
        { init = init
        , view = view
        , update = update
        , subscriptions = subscriptions
        }


mainUrl =
    "/vinapu"



-- "http://localhost:8082/vinapu"


makeOpenDlgButton_ =
    makeOpenDlgButton "col-sm-3"



--"https://192.168.1.48/vinapu"
-- MODEL


type alias DualComboBoxList =
    { first : List ComboBoxItem
    , second : List ComboBoxItem
    }


type alias TripleComboBoxList =
    { first : List ComboBoxItem
    , second : List ComboBoxItem
    , third : List ComboBoxItem
    }


type alias Model =
    { projects : Maybe SelectItems
    , deadloads : Maybe SelectItems
    , liveloads : Maybe SelectItems
    , locations : Maybe SelectItems
    , systems : Maybe SelectItems
    , nodes : Maybe SelectItems
    , elementLoads : Maybe String
    , dlgProj : ModalDialog
    , projName : String
    , dlgLoc : ModalDialog
    , locName : String
    , dlgSys : ModalDialog
    , sysName : String
    , dlgElement : ModalDialog
    , dlgElementLoad : ModalDialog
    , selectedProject : String
    , selectedLocation : String
    , selectedSystem : String
    , elementDesc : String
    , plw : String
    , plateWidth : String
    , load1 : String
    , loadFactor1 : String
    , formFactor1 : String
    , load2 : String
    , loadFactor2 : String
    , formFactor2 : String
    , node1 : String
    , node2 : String
    }


initModel : Model
initModel =
    { projects = Nothing
    , deadloads = Nothing
    , liveloads = Nothing
    , locations = Nothing
    , systems = Nothing
    , nodes = Nothing
    , elementLoads = Nothing
    , dlgProj = dlgClose
    , projName = ""
    , dlgLoc = dlgClose
    , locName = ""
    , dlgSys = dlgClose
    , sysName = ""
    , dlgElement = dlgClose
    , dlgElementLoad = dlgClose
    , selectedProject = "-1"
    , selectedLocation = "-1"
    , selectedSystem = "-1"
    , elementDesc = ""
    , plw = "0.5"
    , plateWidth = "5.0"
    , load1 = "-1"
    , loadFactor1 = "5.0"
    , formFactor1 = "1.0"
    , load2 = "-1"
    , loadFactor2 = "5.0"
    , formFactor2 = "1.0"
    , node1 = "-1"
    , node2 = "-1"
    }



-- MSG


type Msg
    = ProjectsFetched (Result Http.Error TripleComboBoxList)
    | FetchLocations String
    | LocationsFetched (Result Http.Error SelectItems)
    | FetchSystems String
    | SystemsFetched (Result Http.Error DualComboBoxList)
    | FetchElementLoads String
    | ElementLoadsFetched (Result Http.Error String)
    | ProjOpen
    | ProjOk
    | ProjCancel
    | ProjNameChange String
    | OnNewProject Int
    | LocOpen
    | LocOk
    | LocCancel
    | LocNameChange String
    | OnNewLocation Int
    | SysOpen
    | SysOk
    | SysCancel
    | SysNameChange String
    | OnNewSystem Int
    | ElementOpen
    | ElementOk
    | ElementCancel
    | ElementDescChange String
    | ElementLoadOpen
    | ElementLoadOk
    | ElementLoadCancel
    | PlwChange String
    | PlateWidthChange String
    | Load1Selected String
    | LoadFactor1Change String
    | FormFactor1Change String
    | Load2Selected String
    | LoadFactor2Change String
    | FormFactor2Change String
    | Node1Selected String
    | Node2Selected String



-- INIT


init : ( Model, Cmd Msg )
init =
    ( initModel, fetchProjects )



-- UPDATE


emptyComboBoxItem : ComboBoxItem
emptyComboBoxItem =
    ComboBoxItem "-1" "-"


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        ProjectsFetched (Ok s) ->
            ( { model
                | projects = Just s.first
                , deadloads = Just s.second
                , liveloads = Just s.third
                , selectedLocation = "-1"
                , selectedSystem = "-1"
                , locations = Nothing
                , systems = Nothing
                , elementLoads = Nothing
              }
            , Cmd.none
            )

        ProjectsFetched (Err s) ->
            Debug.log "ProjectsFetched Error" ( model, Cmd.none )

        FetchLocations s ->
            ( { model | selectedProject = s }, fetchLocations s )

        LocationsFetched (Ok s) ->
            ( { model
                | locations = Just s
                , selectedLocation = "-1"
                , selectedSystem = "-1"
                , systems = Nothing
                , elementLoads = Nothing
              }
            , Cmd.none
            )

        LocationsFetched (Err _) ->
            Debug.log "LocationsFetched Error" ( model, Cmd.none )

        FetchSystems s ->
            ( { model | selectedLocation = s }, fetchSystems s )

        SystemsFetched (Ok s) ->
            ( { model | systems = Just s.first, nodes = Just s.second, elementLoads = Nothing }, Cmd.none )

        SystemsFetched (Err _) ->
            Debug.log "SystemsFetched Error" ( model, Cmd.none )

        FetchElementLoads s ->
            ( { model | selectedSystem = s }, fetchElementLoads s )

        ElementLoadsFetched (Ok s) ->
            ( { model | elementLoads = Just s }, Cmd.none )

        ElementLoadsFetched (Err _) ->
            Debug.log "ElementLoadsFetched Error" ( model, Cmd.none )

        ProjOpen ->
            ( { model | dlgProj = dlgOpen }, Cmd.none )

        ProjOk ->
            ( { model | dlgProj = dlgClose }, addNewProject model.projName )

        ProjCancel ->
            ( { model | dlgProj = dlgClose }, Cmd.none )

        ProjNameChange s ->
            ( { model | projName = s }, Cmd.none )

        OnNewProject newOid ->
            ( { model
                | projects = updateComboBoxItems newOid model.projName model.projects
                , locations = Nothing
                , systems = Nothing
                , elementLoads = Nothing
              }
            , Cmd.none
            )

        LocOpen ->
            ( { model | dlgLoc = dlgOpen }, Cmd.none )

        LocOk ->
            ( { model | dlgLoc = dlgClose }, addNewLocation model.selectedProject model.locName )

        LocCancel ->
            ( { model | dlgLoc = dlgClose }, Cmd.none )

        LocNameChange s ->
            ( { model | locName = s }, Cmd.none )

        OnNewLocation newOid ->
            ( { model
                | locations = updateComboBoxItems newOid model.locName model.locations
                , systems = Nothing
                , elementLoads = Nothing
              }
            , Cmd.none
            )

        SysOpen ->
            ( { model | dlgSys = dlgOpen }, Cmd.none )

        SysOk ->
            ( { model | dlgSys = dlgClose }, addNewSystem model.selectedLocation model.sysName )

        SysCancel ->
            ( { model | dlgSys = dlgClose }, Cmd.none )

        SysNameChange s ->
            ( { model | sysName = s }, Cmd.none )

        OnNewSystem newOid ->
            ( { model
                | systems = updateComboBoxItems newOid model.sysName model.systems
                , elementLoads = Nothing
              }
            , Cmd.none
            )

        ElementOpen ->
            ( { model | dlgElement = dlgOpen }, Cmd.none )

        ElementOk ->
            Debug.log "ElementOk"
                ( { model | dlgElement = dlgClose }, Cmd.none )

        ElementCancel ->
            ( { model | dlgElement = dlgClose }, Cmd.none )

        ElementDescChange s ->
            Debug.log "ElementDescChange"
                ( { model | elementDesc = s }, Cmd.none )

        PlwChange s ->
            Debug.log "PlwChange"
                ( { model | plw = s }, Cmd.none )

        PlateWidthChange s ->
            Debug.log "PlateWidthChange"
                ( model, Cmd.none )

        ElementLoadOpen ->
            ( model, Cmd.none )

        ElementLoadOk ->
            ( model, Cmd.none )

        ElementLoadCancel ->
            ( model, Cmd.none )

        Load1Selected s ->
            Debug.log "Load1Selected"
                ( { model | load1 = s }, Cmd.none )

        LoadFactor1Change s ->
            Debug.log "LoadFactor1Change"
                ( { model | loadFactor1 = s }, Cmd.none )

        FormFactor1Change s ->
            Debug.log "FormFactor1Change"
                ( { model | formFactor1 = s }, Cmd.none )

        Load2Selected s ->
            Debug.log "Load2Selected"
                ( { model | load2 = s }, Cmd.none )

        LoadFactor2Change s ->
            Debug.log "LoadFactor2Change"
                ( { model | loadFactor2 = s }, Cmd.none )

        FormFactor2Change s ->
            Debug.log "FormFactor2Change"
                ( { model | formFactor2 = s }, Cmd.none )

        Node1Selected s ->
            Debug.log "Node1Selected"
                ( { model | node1 = s }, Cmd.none )

        Node2Selected s ->
            Debug.log "Node2Selected"
                ( { model | node2 = s }, Cmd.none )



-- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.none



-- VIEW


view : Model -> H.Html Msg
view model =
    let
        elementLoadsTable =
            case model.elementLoads of
                Nothing ->
                    H.div [ A.class "col-sm-12" ] []

                Just elementLoadsContent ->
                    H.div [ A.class "col-sm-12", A.property "innerHTML" (JE.string elementLoadsContent) ] []
    in
        H.div [ A.class "container" ]
            [ H.div [ A.class "row" ]
                [ makeOpenDlgButton_ "New project" ProjOpen
                , makeOpenDlgButton_ "New location" LocOpen
                , makeOpenDlgButton_ "New system" SysOpen
                , makeOpenDlgButton_ "New element" ElementOpen
                ]
            , H.div [ A.class "row" ]
                [ makeSelect "Projects: " FetchLocations model.projects model.selectedProject
                , makeSelect "Locations: " FetchSystems model.locations model.selectedLocation
                , makeSelect "Systems: " FetchElementLoads model.systems model.selectedSystem
                ]
            , H.div [ A.class "row" ]
                [ elementLoadsTable
                ]
            , modalDialog "New project"
                model.dlgProj
                ProjOk
                ProjCancel
                [ makeInput ProjNameChange
                ]
            , modalDialog ("New Location for Project id: " ++ model.selectedProject)
                model.dlgLoc
                LocOk
                LocCancel
                [ makeLabel "Location Name:"
                , makeInput LocNameChange
                ]
            , modalDialog ("New System for Location id: " ++ model.selectedLocation)
                model.dlgSys
                SysOk
                SysCancel
                [ makeLabel "System Name:"
                , makeInput SysNameChange
                ]
            , modalDialog ("New Element for System id: " ++ model.selectedSystem)
                model.dlgElement
                ElementOk
                ElementCancel
                [ H.ul [ A.class "nav nav-tabs" ]
                    [ H.li [ A.class "active" ]
                        [ H.a [ A.href "#geo1", A.attribute "data-toggle" "pill" ]
                            [ H.text "Geometry" ]
                        ]
                    , H.li []
                        [ H.a [ A.href "#loads1", A.attribute "data-toggle" "pill" ]
                            [ H.text "Loads" ]
                        ]
                    ]
                , H.div [ A.class "tab-content" ]
                    [ H.div [ A.id "geo1", A.class "tab-pane in active" ]
                        [ makeFGRInput ElementDescChange "id1" "Element desc:" "text" CM.CX39 model.elementDesc
                        , makeFGRSelect "id2" "Node 1:" CM.CX39 model.nodes (Just Node1Selected)
                        , makeFGRSelect "id3" "Node 2:" CM.CX39 model.nodes (Just Node2Selected)
                        , makeFGRInput PlwChange "id4" "Load distribution factor:" "number" CM.CX66 model.plw
                        , makeFGRInput PlateWidthChange "id5" "Plate width:" "number" CM.CX66 model.plateWidth
                        ]
                    , H.div [ A.id "loads1", A.class "tab-pane" ]
                        [ makeFGRSelect "id6" "Dead load:" CM.CX39 model.deadloads (Just Load1Selected)
                        , makeFGRInput LoadFactor1Change "id7" "Load factor dead load:" "number" CM.CX66 model.loadFactor1
                        , makeFGRInput FormFactor1Change "id8" "Form factor dead load:" "number" CM.CX66 model.formFactor1
                        , makeFGRSelect "id9" "Live load:" CM.CX39 model.liveloads (Just Load2Selected)
                        , makeFGRInput LoadFactor2Change "id10" "Load factor dead load:" "number" CM.CX66 model.loadFactor2
                        , makeFGRInput FormFactor2Change "id11" "Form factor dead load:" "number" CM.CX66 model.formFactor2
                        ]
                    ]
                ]
            ]



-- COMMANDS


asHttpBody : List ( String, JE.Value ) -> Http.Body
asHttpBody lx =
    let
        x =
            JE.object lx
    in
        Http.stringBody "application/json" (JE.encode 0 x)


addNewDbItem : String -> List ( String, JE.Value ) -> (Int -> Msg) -> Cmd Msg
addNewDbItem urlAction params msg =
    Cmd.none



{-
   let
       url =
           mainUrl ++ urlAction

       pnBody =
           asHttpBody params
   in
       Http.post Json.int url pnBody
           |> Task.mapError toString
           |> Task.perform FetchFail msg
-}


addNewProject : String -> Cmd Msg
addNewProject pn =
    addNewDbItem "/newproject" [ ( "pn", JE.string pn ) ] OnNewProject


addNewLocation : String -> String -> Cmd Msg
addNewLocation pid loc =
    case String.toInt pid of
        Ok pidx ->
            addNewDbItem "/newlocation" [ ( "pid", JE.int pidx ), ( "loc", JE.string loc ) ] OnNewLocation

        Err errMsg ->
            Cmd.none


addNewSystem : String -> String -> Cmd Msg
addNewSystem loc sys =
    case String.toInt loc of
        Ok locx ->
            addNewDbItem "/newsystem" [ ( "loc", JE.int locx ), ( "sys", JE.string sys ) ] OnNewSystem

        Err errMsg ->
            Cmd.none


fetchProjects : Cmd Msg
fetchProjects =
    let
        myDecoder =
            Json.map3
                TripleComboBoxList
                (field "projects" comboBoxItemListDecoder)
                (field "deadloads" comboBoxItemListDecoder)
                (field "liveloads" comboBoxItemListDecoder)

        myUrl =
            (mainUrl ++ "/projects")
    in
        Http.send ProjectsFetched <|
            Http.get myUrl myDecoder


fetchLocations : String -> Cmd Msg
fetchLocations s =
    let
        myUrl =
            (mainUrl ++ "/locations?oid=" ++ s)
    in
        Http.send LocationsFetched <|
            Http.get myUrl comboBoxItemListDecoder


fetchSystems : String -> Cmd Msg
fetchSystems s =
    let
        myDecoder =
            Json.map2
                DualComboBoxList
                (field "systems" comboBoxItemListDecoder)
                (field "nodes" comboBoxItemListDecoder)

        myUrl =
            (mainUrl ++ "/systems?oid=" ++ s)
    in
        Http.send SystemsFetched <|
            Http.get myUrl myDecoder


fetchElementLoads : String -> Cmd Msg
fetchElementLoads s =
    let
        url =
            mainUrl ++ "/elementloads?oid=" ++ s
    in
        Http.send ElementLoadsFetched <|
            Http.getString url
