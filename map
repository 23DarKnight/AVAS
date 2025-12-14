#!/usr/bin/python3
import sys
from functools import lru_cache
import os
from math import radians, sin, cos, sqrt, atan2
from PySide6 import QtCore
from PySide6.QtWidgets import QApplication, QMainWindow, QGraphicsView, QGraphicsScene, QVBoxLayout, QWidget, QLabel, \
    QPushButton, QGraphicsProxyWidget, QDialog, QCheckBox, QComboBox, QLineEdit, QVBoxLayout, QGridLayout, QSizePolicy, QTextEdit, QMessageBox
from PySide6.QtGui import QPixmap, QImage, QIcon
from PySide6.QtCore import Qt, QTimer, QPoint, QPointF, QRect, Signal
from PIL import Image, ImageDraw, ImageFont
from functools import partial
import math
import time
import mysql.connector
from cryptography.hazmat.primitives.ciphers import Cipher, algorithms, modes
from cryptography.hazmat.backends import default_backend
from cryptography.hazmat.primitives import padding
import configparser
import indiagrid
import hashlib
from pathlib import Path
import pickle
from pyproj import CRS, Transformer
import logging



# Load the configuration file
config = configparser.ConfigParser()
config.read("/etc/parth/parth.conf")

id = config["host"]["id"]


##   DSM conversion for 5D zone under epsm 7755 refer to t2
wkt = f"""
PROJCS["WGS 84 (8E)/ India NSF LCC",
    GEOGCS["WGS 84",
        DATUM["WGS_1984",
            SPHEROID["WGS 84",6378137,298.257223563,
                AUTHORITY["EPSG","7030"]],
            AUTHORITY["EPSG","6326"]],
        PRIMEM["Greenwich",0,
            AUTHORITY["EPSG","8901"]],
        UNIT["degree",0.0174532925199433,
            AUTHORITY["EPSG","9122"]],
        AUTHORITY["EPSG","4326"]],
    PROJECTION["Lambert_Conformal_Conic_2SP"],
    PARAMETER["latitude_of_origin",33.00884444439991],
    PARAMETER["central_meridian", 72],
    PARAMETER["standard_parallel_1",30.85722222220049],
    PARAMETER["standard_parallel_2", 35.14277777780055],
    PARAMETER["false_easting",500000],
    PARAMETER["false_northing",500000],
    UNIT["metre",1,
        AUTHORITY["EPSG","9001"]],
    AXIS["Easting",EAST],
    AXIS["Northing",NORTH],
    AUTHORITY["EPSG","7755"]]
"""
crs_custom = CRS.from_wkt(wkt)
crs_wgs84 = CRS.from_epsg(4326)



@lru_cache(maxsize=100000)  # Cache up to 100 tiles
def load_tile(x, y):
    tile_folder = "/usr/share/tiles/17"
    tile_path = os.path.join(tile_folder, f"{y}/{x}")
    print(tile_path)
    print("trying to load")
    try:
        tile_image = Image.open(tile_path)
        return tile_image
    except Exception as e:
        print(f"Error loading {tile_path}: {e}")
    return None


def execWriteSql(dbname, query, parameters=()):
    """
    mean to execute sql query to add/delete data in db
    :param dbname:
    :param query:
    :param parameters:
    :return:
    """
    try:
        conn = mysql.connector.connect(
            database=dbname,
            user="radio",
            password="System@68",
            host="localhost",
            auth_plugin='mysql_native_password',
        )

        cursor = conn.cursor()
        cursor.execute(query, parameters)
        conn.commit()
        cursor.close()
        conn.close()

    except Exception as e:
        logging.error(e)


def execReadSql(dbname, query, parameters=()):
    """
    Adds the data into the mentioned table
    :param dbname:
    :param query:
    :param parameters:
    :return fetched data:
    """
    try:
        conn = mysql.connector.connect(
            database=dbname,
            user="radio",
            password="System@68",
            host="localhost",
            auth_plugin='mysql_native_password',
        )

        cursor = conn.cursor()
        cursor.execute(query, parameters)
        data = cursor.fetchall()
        cursor.close()
        conn.close()
        if len(data) > 0:
            return data[0]
        else:
            return None

    except Exception as e:
        logging.error(e)
        return None




def enc(msg):
    with open("/usr/share/parth/aes_key_iv.bin", "rb") as file:
        data = file.read()
        key = data[:16]  # First 16 bytes are the key
        iv = data[16:32]  # Next 16 bytes are the IV
        message = msg.encode('utf-8')  # Convert string to bytes

        # Pad the message to be a multiple of the block size (16 bytes for AES)
        padder = padding.PKCS7(algorithms.AES.block_size).padder()
        padded_data = padder.update(message) + padder.finalize()

        # Create an AES cipher object
        cipher = Cipher(algorithms.AES(key), modes.CBC(iv), backend=default_backend())
        encryptor = cipher.encryptor()

        # Encrypt the padded data
        encrypted_message = encryptor.update(padded_data) + encryptor.finalize()
        return encrypted_message.hex()


def dec(msg):
    with open("/usr/share/parth/aes_key_iv.bin", "rb") as file:
        data = file.read()
        key = data[:16]  # First 16 bytes are the key
        iv = data[16:32]  # Next 16 bytes are the IV

        cipher = Cipher(algorithms.AES(key), modes.CBC(iv), backend=default_backend())
        decryptor = cipher.decryptor()

        # Decrypt the message
        padded_data = decryptor.update(msg) + decryptor.finalize()

        # Unpad the decrypted data
        unpadder = padding.PKCS7(algorithms.AES.block_size).unpadder()
        decrypted_message = unpadder.update(padded_data) + unpadder.finalize()
        return decrypted_message.decode()


def get_loc():
    conn = mysql.connector.connect(
        database="parameters",
        user="gps",
        password="System@68",
        host="localhost",
        auth_plugin='mysql_native_password',
    )

    try:
        cur = conn.cursor()
        cur.execute("select * from aham where id=%s;", (id,))
        sid, lat, lon = cur.fetchone()
        cur.close()
        conn.close()

        return lat, lon
    except Exception as e:
        print(e)
        return 32, 75


def get_team_loc():
    conn = mysql.connector.connect(
        database="parameters",
        user="radio",
        password="System@68",
        host="localhost",
        auth_plugin='mysql_native_password',
    )

    cur = conn.cursor()
    cur.execute("select * from team;")
    lst = cur.fetchall()
    cur.close()
    conn.close()
    return lst


def deg2num(lat_deg, lon_deg, zoom=17):
    lat_rad = math.radians(lat_deg)
    n = 2.0 ** zoom
    x_tile = (lon_deg + 180.0) / 360.0 * n
    y_tile = (1.0 - math.asinh(math.tan(lat_rad)) / math.pi) / 2.0 * n
    return (x_tile, y_tile)


def haversine(lat1, lon1, lat2, lon2):
    """
    Calculate the great-circle distance between two points on Earth using the Haversine formula.

    :param lat1: Latitude of the first point (in decimal degrees)
    :param lon1: Longitude of the first point (in decimal degrees)
    :param lat2: Latitude of the second point (in decimal degrees)
    :param lon2: Longitude of the second point (in decimal degrees)
    :return: Distance in kilometers (float)
    """
    R = 6371.0  # Earth's radius in km

    # Convert degrees to radians
    lat1, lon1, lat2, lon2 = map(radians, [lat1, lon1, lat2, lon2])

    # Haversine formula
    dlat = lat2 - lat1
    dlon = lon2 - lon1
    a = sin(dlat / 2) ** 2 + cos(lat1) * cos(lat2) * sin(dlon / 2) ** 2
    c = 2 * atan2(sqrt(a), sqrt(1 - a))

    return round(R * c, 3)


def num2deg(x_tile, y_tile, zoom=17):
    """
    Convert tile coordinates (x, y) and zoom level to latitude and longitude.

    :param x_tile: X coordinate of the tile
    :param y_tile: Y coordinate of the tile
    :param zoom: Zoom level
    :return: Tuple of (latitude, longitude) in degrees
    """
    n = 2.0 ** zoom
    lon_deg = x_tile / n * 360.0 - 180.0  # Longitude calculation
    lat_rad = math.atan(math.sinh(math.pi * (1 - 2 * y_tile / n)))  # Latitude calculation
    lat_deg = math.degrees(lat_rad)  # Convert latitude to degrees
    return lat_deg, lon_deg


def get_distance_and_bearing(lat1, lon1, lat2, lon2):
    """
    Calculate the distance (in meters) and bearing (in degrees from North)
    between two latitude/longitude coordinates.

    Parameters:
        lat1, lon1: Latitude and Longitude of the first point in decimal degrees
        lat2, lon2: Latitude and Longitude of the second point in decimal degrees

    Returns:
        distance_m: Distance in meters
        bearing_deg: Bearing in degrees from North (0° to 360°)
    """
    # Earth radius in meters
    R = 6371000

    # Convert degrees to radians
    φ1 = math.radians(lat1)
    φ2 = math.radians(lat2)
    Δφ = math.radians(lat2 - lat1)
    Δλ = math.radians(lon2 - lon1)

    # Haversine formula
    a = math.sin(Δφ / 2) ** 2 + math.cos(φ1) * math.cos(φ2) * math.sin(Δλ / 2) ** 2
    c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))
    distance_m = R * c

    # Bearing calculation
    y = math.sin(Δλ) * math.cos(φ2)
    x = math.cos(φ1) * math.sin(φ2) - math.sin(φ1) * math.cos(φ2) * math.cos(Δλ)
    bearing_rad = math.atan2(y, x)
    bearing_deg = (math.degrees(bearing_rad) + 360) % 360

    return distance_m, bearing_deg


def deg2dsm(lat, lon):
    fwd_transformer = Transformer.from_crs(crs_wgs84, crs_custom, always_xy=True)
    easting, northing = fwd_transformer.transform(lon, lat)
    easting = round(easting)
    northing = round(northing)
    return easting, northing

def dsm2deg(easting, northing):
    rev_transformer = Transformer.from_crs(crs_custom, crs_wgs84, always_xy=True)
    lon, lat = rev_transformer.transform(easting, northing)
    lat = round(lat, 6)
    lon = round(lon, 6)
    return lat, lon

def decimal_to_dm(decimal_coord):
    """
    Convert decimal coordinates to degrees, minutes, and seconds (DMS).

    Args:
        decimal_coord (float): Coordinate in decimal degrees.

    Returns:
        tuple: (degrees, minutes, seconds)
    """
    degrees = int(decimal_coord)
    minutes_decimal = abs(decimal_coord - degrees) * 60
    minutes = minutes_decimal

    return f"{degrees}° {round(minutes,5)}'"


def dms_to_decimal(degrees, minutes):
    """
    Converts DMS (Degrees, Minutes, Seconds) to Decimal Degrees (DD).

    :param degrees: int or float, degrees part of the coordinate
    :param minutes: int or float, minutes part of the coordinate
    :param seconds: int or float, seconds part of the coordinate
    :return: float, decimal degrees
    """
    decimal_degrees = abs(degrees) + (minutes / 60)

    # Preserve negative sign for south latitudes & west longitudes
    if degrees < 0:
        decimal_degrees = -decimal_degrees

    return decimal_degrees



def deg2grid(lat, lon):
    """
        Convert latitude and longitude (in decimal degrees) to Easting and Northing
        in the Everest Grid System using pyproj with automatic zone detection.

        Parameters:
        - lat: Latitude in decimal degrees (WGS84)
        - lon: Longitude in decimal degrees (WGS84)

        Returns:
        - (easting, northing, zone): Tuple of Easting (m), Northing (m), and zone name
        """

    a = indiagrid.wgs84_to_igs(lat, lon)

    return a["Easting"], a["Northing"]

class BaseWindow(QWidget):
    def __init__(self):
        super().__init__()
        self.move(10, 10)
        self.setStyleSheet("font-size: 20px;")
        self.closebtn = QPushButton("Close")
        self.closebtn.setStyleSheet("background-color: red;")
        self.closebtn.setFixedSize(QtCore.QSize(500, 60))
        self.setMinimumSize(300,400)

        self.closebtn.clicked.connect(self.close)

        self.layout = QVBoxLayout()
        self.layout.addWidget(self.closebtn)

        self.setLayout(self.layout)

    def addBtns(self, btnLst):
        for btnName in btnLst.keys():
            btn = QPushButton(btnName)
            btn.clicked.connect(btnLst[btnName])
            self.layout.addWidget(btn)



class NavigMenu(QWidget):
    routefile = "/usr/share/parth/routes.pkl"
    def __init__(self):
        super().__init__()
        self.addcoord = None
        self.setWindowTitle("Popup")
        self.move(10,10)
        self.setStyleSheet("font-size: 20px;")
        self.closebtn = QPushButton("Close")
        self.closebtn.setStyleSheet("background-color: red;")
        self.closebtn.clicked.connect(self.close)
        f = open(self.routefile, "rb")
        self.data = pickle.load(f)
        f.close()

        layout = QVBoxLayout()
        layout.addWidget(self.closebtn)

        btns = {
            "Point Nav": self.point_to_point,
            "Create Route": self.add_rounte,
            "Routes": self.routes
        }

        for key, value in btns.items():
            enter_button = QPushButton(key, self)
            enter_button.setFixedSize(QtCore.QSize(500, 80))
            enter_button.clicked.connect(value)
            layout.addWidget(enter_button)

        self.setLayout(layout)

    def point_to_point(self):
        nav = CoordinatePopup()
        nav.show()

    def add_rounte(self):
        routenameinp = KeyboardInput(self, "Enter Route Name: ")
        routenameinp.exec()
        self.data[self.routename] = {}
        f = open(self.routefile, "wb")
        pickle.dump(self.data, f)
        f.close()
        self.modroute(self.routename)


    def routes(self):
        f =  open(self.routefile, "rb")
        self.data = pickle.load(f)
        f.close()
        self.routewin = BaseWindow()
        self.routewin.setWindowTitle("Routes")

        grid = QGridLayout()
        row = 0

        for routename in self.data.keys():
            text = QLabel(routename)
            delbtn = QPushButton("🗑️")
            startbtn = QPushButton("Start")
            modbtn = QPushButton("Edit")
            startbtn.clicked.connect(partial(self.startroute, routename))
            modbtn.clicked.connect(partial(self.modroute, routename))
            delbtn.clicked.connect(partial(self.delroute, routename))
            grid.addWidget(text, row, 0)
            grid.addWidget(startbtn, row, 1)
            grid.addWidget(modbtn, row, 2)
            grid.addWidget(delbtn, row, 3)
            row+=1

        self.routewin.layout.addLayout(grid)

        self.routewin.show()

    def startroute(self, routename):
        window.navlst = list(self.data[routename].values())
        window.target_nav = window.navlst[0]
        window.navlst.pop(0)
        window.navigating = True

    def delroute(self, routename):
        self.data.pop(routename)
        f = open(self.routefile, "wb")
        pickle.dump(self.data, f)
        f.close()
        self.routewin.close()
        self.routes()

    def modroute(self, routename):
        self.modwin = BaseWindow()
        grid = QGridLayout()
        grid.addWidget(QLabel(routename), 0, 0)
        startbtn = QPushButton("Start")
        startbtn.clicked.connect(partial(self.startroute, routename))
        addwayptbtn = QPushButton("Add Waypoint")
        addwayptbtn.clicked.connect(partial(self.addwaypt, routename))
        grid.addWidget(startbtn, 0, 1)
        grid.addWidget(addwayptbtn, 0, 2)
        row = 1
        for k, wp in self.data[routename].items():
            btn = QPushButton("🗑️")
            btn.clicked.connect(partial(self.delwaypt, routename, k))
            grid.addWidget(QLabel(f"Waypoint {row}: "), row, 0)
            grid.addWidget(QLabel(str(wp[0])), row, 1)
            grid.addWidget(QLabel(str(wp[1])), row, 2)
            grid.addWidget(btn, row, 3)
            row+=1
        self.modwin.layout.addLayout(grid)
        self.modwin.show()


    def addwaypt(self, routename):
        self.addwpwin = valueInp2(self)
        self.addwpwin.exec()
        indx = len(list(self.data[routename].keys()))+1
        self.data[routename][str(indx)] = self.addcoord
        f = open(self.routefile, "wb")
        pickle.dump(self.data, f)
        f.close()
        self.modwin.close()
        self.modroute(routename)

    def delwaypt(self, routename, wp):
        for i in range(int(wp), len(list(self.data[routename].values()))):
            self.data[routename][str(i)] = self.data[routename][str(i+1)]
        self.data[routename].pop(str(len(list(self.data[routename]))))
        self.modwin.close()
        f = open(self.routefile, "wb")
        pickle.dump(self.data, f)
        f.close()
        self.modroute(routename)
        raise ValueError(self.data)



class valueInp2(QDialog):
    def __init__(self, prntproc):
        super().__init__()
        self.prntproc = prntproc
        self.setWindowTitle("Popup")
        self.move(10,10)
        self.setStyleSheet("font-size: 20px;")
        self.closebtn = QPushButton("Close")
        self.closebtn.setStyleSheet("background-color: red;")
        self.closebtn.clicked.connect(self.close)

        layout = QVBoxLayout()
        layout.addWidget(self.closebtn)

        # Coordinate Inputs
        self.inputs = [QLineEdit(self) for _ in range(2)]

        # Labels & Input Fields
        grid = QGridLayout()

        # add the lable and input field
        grid.addWidget(QLabel("Easting", self), 0, 0)
        grid.addWidget(self.inputs[0], 0, 1)
        grid.addWidget(QLabel("Northing", self), 0, 2)
        grid.addWidget(self.inputs[1], 0, 3)

        layout.addLayout(grid)

        # Numpad Layout
        self.numpad_input = None  # Track which field is active
        numpad_layout = QGridLayout()
        self.create_numpad(numpad_layout)

        layout.addLayout(numpad_layout)

        # Enter Button
        enter_button = QPushButton("Enter", self)
        enter_button.clicked.connect(partial(self.process_data))
        enter_button.setFixedSize(QtCore.QSize(500, 80))
        layout.addWidget(enter_button)

        self.setLayout(layout)

        # Connect input fields to track active field
        for field in self.inputs:
            field.mousePressEvent = lambda event, f=field: self.set_active_field(f)
            field.setFixedSize(QtCore.QSize(150, 50))


    def create_numpad(self, layout):
        """Creates a numpad with buttons 0-9 and backspace."""
        buttons = [
            ('7', 0, 0), ('8', 0, 1), ('9', 0, 2),
            ('4', 1, 0), ('5', 1, 1), ('6', 1, 2),
            ('1', 2, 0), ('2', 2, 1), ('3', 2, 2),
            ('0', 3, 1), ('.', 3, 0), ('⌫', 3, 2)  # ⌫ for backspace
        ]

        for text, row, col in buttons:
            button = QPushButton(text, self)
            button.setFixedSize(QtCore.QSize(50, 50))
            button.clicked.connect(lambda _, t=text: self.numpad_press(t))
            layout.addWidget(button, row, col)

    def set_active_field(self, field):
        """Set the currently active input field."""
        self.numpad_input = field

    def numpad_press(self, value):
        """Handles numpad button presses."""
        if self.numpad_input:
            if value == "⌫":
                self.numpad_input.setText(self.numpad_input.text()[:-1])  # Backspace
            else:
                self.numpad_input.setText(self.numpad_input.text() + value)  # Append number


    def process_data(self):
        """Gets values from input fields and calls demo() function."""
        try:
            easting = float(self.inputs[0].text())
            northing = float(self.inputs[1].text())
            # convert the coordinates from igs input to lat lon
            lat, lon = dsm2deg(easting, northing)
            self.prntproc.addcoord = [round(float(lat), 6), round(float(lon), 6)]
            self.close()
        except ValueError:
            print("Invalid input! Please enter valid numbers.")



class CoordinatePopup(QWidget):
    def __init__(self):
        super().__init__()

        self.setWindowTitle("Popup")
        self.move(10,10)
        self.setStyleSheet("font-size: 20px;")
        self.closebtn = QPushButton("Close")
        self.closebtn.setStyleSheet("background-color: red;")
        self.closebtn.clicked.connect(self.close)

        layout = QVBoxLayout()
        layout.addWidget(self.closebtn)

        # Coordinate Inputs
        self.inputs = [QLineEdit(self) for _ in range(2)]

        # Labels & Input Fields
        grid = QGridLayout()

        # add the lable and input field
        grid.addWidget(QLabel("Easting", self), 0, 0)
        grid.addWidget(self.inputs[0], 0, 1)
        grid.addWidget(QLabel("Northing", self), 0, 2)
        grid.addWidget(self.inputs[1], 0, 3)

        layout.addLayout(grid)

        # Numpad Layout
        self.numpad_input = None  # Track which field is active
        numpad_layout = QGridLayout()
        self.create_numpad(numpad_layout)

        layout.addLayout(numpad_layout)

        # Enter Button
        enter_button = QPushButton("Enter", self)
        enter_button.clicked.connect(self.process_data)
        enter_button.setFixedSize(QtCore.QSize(500, 80))
        layout.addWidget(enter_button)

        self.setLayout(layout)

        # Connect input fields to track active field
        for field in self.inputs:
            field.mousePressEvent = lambda event, f=field: self.set_active_field(f)
            field.setFixedSize(QtCore.QSize(150, 50))


    def create_numpad(self, layout):
        """Creates a numpad with buttons 0-9 and backspace."""
        buttons = [
            ('7', 0, 0), ('8', 0, 1), ('9', 0, 2),
            ('4', 1, 0), ('5', 1, 1), ('6', 1, 2),
            ('1', 2, 0), ('2', 2, 1), ('3', 2, 2),
            ('0', 3, 1), ('.', 3, 0), ('⌫', 3, 2)  # ⌫ for backspace
        ]

        for text, row, col in buttons:
            button = QPushButton(text, self)
            button.setFixedSize(QtCore.QSize(50, 50))
            button.clicked.connect(lambda _, t=text: self.numpad_press(t))
            layout.addWidget(button, row, col)

    def set_active_field(self, field):
        """Set the currently active input field."""
        self.numpad_input = field

    def numpad_press(self, value):
        """Handles numpad button presses."""
        if self.numpad_input:
            if value == "⌫":
                self.numpad_input.setText(self.numpad_input.text()[:-1])  # Backspace
            else:
                self.numpad_input.setText(self.numpad_input.text() + value)  # Append number


    def process_data(self):
        """Gets values from input fields and calls demo() function."""
        try:
            easting = float(self.inputs[0].text())
            northing = float(self.inputs[1].text())
            # convert the coordinates from igs input to lat lon
            lat, lon = dsm2deg(easting, northing)
            window.navigating = True
            window.target_nav = (float(lat), float(lon))
        except ValueError:
            print("Invalid input! Please enter valid numbers.")


class KeyboardInput(QDialog):
    def __init__(self, prntproc, titlename):
        super().__init__()
        self.move(10,10)
        self.setMinimumSize(500,500)
        self.setStyleSheet("font-size: 20px;")
        self.closebtn = QPushButton("Close")
        self.closebtn.setStyleSheet("background-color: red;")
        self.closebtn.clicked.connect(self.close)

        self.prntproc = prntproc

        self.label = QLabel(titlename)
        self.password_input = QLineEdit()
        # self.password_input.setEchoMode(QLineEdit.Password)

        self.submit_button = QPushButton("Submit")
        self.submit_button.clicked.connect(self.check_password)

        layout = QVBoxLayout()
        layout.addWidget(self.closebtn)
        layout.addWidget(self.label)
        layout.addWidget(self.password_input)
        layout.addLayout(self.create_virtual_keyboard())
        layout.addWidget(self.submit_button)

        self.setLayout(layout)

    def create_virtual_keyboard(self):
        keys = list("1234567890ABCDEFGHIJKLMNOPQRSTUVWXYZ")
        grid_layout = QGridLayout()

        row, col = 0, 0
        for key in keys:
            button = QPushButton(key)
            button.setFixedSize(40, 40)
            button.clicked.connect(lambda checked, char=key: self.password_input.insert(char))
            grid_layout.addWidget(button, row, col)
            col += 1
            if col >= 10:
                col = 0
                row += 1

        backspace_btn = QPushButton("⌫")
        backspace_btn.clicked.connect(self.backspace)
        grid_layout.addWidget(backspace_btn, row + 1, 0)

        clear_btn = QPushButton("Clear")
        clear_btn.clicked.connect(self.password_input.clear)
        grid_layout.addWidget(clear_btn, row + 1, 1, 1, 2)

        return grid_layout

    def backspace(self):
        current_text = self.password_input.text()
        self.password_input.setText(current_text[:-1])

    def check_password(self):
        self.prntproc.routename = self.password_input.text()
        self.close()


# lock screen
class PasswordDialog(QWidget):
    authenticated = Signal()

    def __init__(self):
        super().__init__()
        self.setWindowTitle("Enter Password")
        self.setGeometry(10, 10, 800, 800)

        self.label = QLabel("Enter password:")
        self.password_input = QLineEdit()
        self.password_input.setEchoMode(QLineEdit.Password)

        self.submit_button = QPushButton("Submit")
        self.submit_button.clicked.connect(self.check_password)

        layout = QVBoxLayout()
        layout.addWidget(self.label)
        layout.addWidget(self.password_input)
        layout.addLayout(self.create_virtual_keyboard())
        layout.addWidget(self.submit_button)

        self.setLayout(layout)

    def create_virtual_keyboard(self):
        keys = list("1234567890ABCDEFGHIJKLMNOPQRSTUVWXYZ")
        grid_layout = QGridLayout()

        row, col = 0, 0
        for key in keys:
            button = QPushButton(key)
            button.setFixedSize(40, 40)
            button.clicked.connect(lambda checked, char=key: self.password_input.insert(char))
            grid_layout.addWidget(button, row, col)
            col += 1
            if col >= 10:
                col = 0
                row += 1

        backspace_btn = QPushButton("⌫")
        backspace_btn.clicked.connect(self.backspace)
        grid_layout.addWidget(backspace_btn, row + 1, 0)

        clear_btn = QPushButton("Clear")
        clear_btn.clicked.connect(self.password_input.clear)
        grid_layout.addWidget(clear_btn, row + 1, 1, 1, 2)

        return grid_layout

    def backspace(self):
        current_text = self.password_input.text()
        self.password_input.setText(current_text[:-1])

    def check_password(self):
        entered_password = self.password_input.text()
        entered_hash = hashlib.sha256(entered_password.encode()).hexdigest()

        try:
            passwd_file = Path("/etc/parth/passwd")
            if not passwd_file.exists():
                QMessageBox.critical(self, "Error", "Password file not found.")
                QApplication.quit()
                return

            stored_hash = passwd_file.read_text().strip()
            if entered_hash == stored_hash:
                self.authenticated.emit()
            else:
                QMessageBox.critical(self, "Error", "Incorrect password.")
                print(entered_hash, entered_password)
                QApplication.quit()

        except Exception as e:
            QMessageBox.critical(self, "Error", f"Failed to read password: {e}")
            QApplication.quit()





class CustomGraphicsScene(QGraphicsScene):
    def __init__(self):
        super().__init__()
        self.panel_proxy = None
        self.label = None
        self.panel = None
        self.dragging = False  # Flag to track dragging state
        self.start_point = ()  # Store the starting point of the drag
        # mouse dragging captures config
        self.last_mouse_pos = QPoint()

    def mousePressEvent(self, event):
        """Handle mouse press event."""
        if event.button() == Qt.MouseButton.LeftButton:
            x_range = window.home_btn_bbox[0], window.home_btn_bbox[2]
            y_range = window.home_btn_bbox[1], window.home_btn_bbox[3]
            if event.scenePos().x() in range(x_range[0], x_range[1]) and event.scenePos().y() in range(y_range[0],
                                                                                                       y_range[1]):
                window.homing()
            elif event.scenePos().x() in range(x_range[0], x_range[1]) and event.scenePos().y() in range(window.screen_height-150, window.screen_height-75):
                print("zooming out")
                window.zoomOut()
            elif event.scenePos().x() in range(x_range[0], x_range[1]) and event.scenePos().y() in range(window.screen_height-225, window.screen_height-150):
                window.zoomIn()
                print("zooming in ")
            elif event.scenePos().x() in range(x_range[0], x_range[1]) and event.scenePos().y() in range(window.screen_height-300, window.screen_height-225):
                window.navigate()
            else:
                window.touch_timer = time.time()
                window.touch_point = event.scenePos()
                self.dragging = True
                self.start_point = event.scenePos()  # Get the scene position of the click
        super().mousePressEvent(event)  # Propagate the event

    def mouseMoveEvent(self, event):
        """Handle mouse move event."""
        if self.dragging:
            current_point = event.scenePos()  # Get the current scene position
            diff_x = float(self.start_point.x() - current_point.x()) / window.tile_size
            diff_y = float(self.start_point.y() - current_point.y()) / window.tile_size
            self.start_point = event.scenePos()

            if int(diff_x * window.tile_size) != 0 and int(diff_y * window.tile_size) != 0:
                window.auto_home = False
            window.center_x += diff_x
            window.center_y += diff_y
        super().mouseMoveEvent(event)  # Propagate the event

    def mouseReleaseEvent(self, event):
        """Handle mouse release event."""
        if event.button() == Qt.MouseButton.LeftButton:
            self.dragging = False
            x = int((event.scenePos().x() - window.touch_point.x()) * 1000)
            y = int((event.scenePos().y() - window.touch_point.y()) * 1000)
            if (x, y) == (0, 0) and time.time() >= window.touch_threshold:
                window.show_func_panel(event.scenePos())
        super().mouseReleaseEvent(event)  # Propagate the event


class PopupWindow(QDialog):
    def __init__(self):
        super().__init__()

        # Set the window title and size
        self.setWindowTitle("Popup Window")
        # self.setFixedSize(300, 200)  # Set pop-up size
        self.move(10,10)
        self.setMinimumSize(200,200)
        self.setStyleSheet("font-size: 20px;")
        self.btn = QPushButton("Close")
        self.btn.setStyleSheet("""
            QPushButton {
                background-color: red;
            }
        """)
        self.btn.clicked.connect(self.close)
        # Make the pop-up modal
        self.setModal(True)

        # Create a layout for the pop-up window
        self.layout = QVBoxLayout()
        self.layout.addWidget(self.btn)

        # Set the layout for the pop-up window
        self.setLayout(self.layout)

        self.timer = QTimer()
        self.timer.timeout.connect(self.close)  # Connect the timer to the close method
        self.timer.start(20000)  # 15 seconds in milliseconds



class MyApp(QMainWindow):

    def __init__(self):
        # tile settings
        super().__init__()
        self.home_btn_bbox = None
        self.frame_dim = [92851, 92856.4296875, 53393, 53396.125]  # x1 x2 y1 y2
        self.frame_dim_prev = [92851, 92856.4296875, 53393, 53396.125]  # x1 x2 y1 y2
        # self.screen_width = app.primaryScreen().size().width()
        self.screen_width = 1280
        # self.screen_height = app.primaryScreen().size().height()
        self.screen_height = 800
        self.tile_size = 256
        self.tile_size_prev = 256
        self.zoom = 17
        self.min_x, self.min_y = 45875, 25508
        self.max_x, self.max_y = 46967, 27038
        self.center_x = 0
        self.center_y = 0
        self.auto_home = False
        # for navigations
        self.target_nav = (0, 0)
        self.navlst = []
        self.navigating = False

        # config for touch and hold
        self.touch_threshold = 2
        self.touch_timer = 0
        self.touch_point = None

        self.droppin_x = 0
        self.droppin_y = 0

        self.enPos = {}

        self.setMouseTracking(True)

        # Set the window title and size
        self.setWindowTitle("Netra")
        self.setGeometry(0, 0, self.screen_width, self.screen_height)  # (x, y, width, height)

        self.screen_width = int((self.screen_width*0.97)/2)*2
        # self.screen_height = int((self.screen_height*0.97)/2)*2
        self.map = Image.new("RGB", (self.screen_width, self.screen_height))
        self.frame = Image.new("RGB", (self.screen_width, self.screen_height))

        # Create a central widget and set the layout
        central_widget = QWidget()
        self.setCentralWidget(central_widget)
        layout = QVBoxLayout()

        # Create a QGraphicsView and QGraphicsScene to display the map
        self.view = QGraphicsView()
        self.scene = CustomGraphicsScene()
        self.view.setScene(self.scene)
        layout.addWidget(self.view)

        self.show()
        central_widget.setLayout(layout)

        self.my_loc = get_loc()
        self.center_x, self.center_y = deg2num(self.my_loc[0], self.my_loc[1])
        self.initialize_map()
        self.frame = self.map.copy()
        # Set up a QTimer to update the scene periodically
        self.timer = QTimer()
        self.timer.timeout.connect(self.main)
        self.timer.start(50)  # Update every 1000 ms (1 second)

    def update_viewport(self):
        self.frame_dim_prev = self.frame_dim.copy()
        if self.auto_home:
            self.center_x, self.center_y = deg2num(self.my_loc[0], self.my_loc[1])
        self.frame_dim[0] = self.center_x - (self.screen_width / self.tile_size) / 2
        self.frame_dim[1] = self.center_x + (self.screen_width / self.tile_size) / 2
        self.frame_dim[2] = self.center_y - (self.screen_height / self.tile_size) / 2
        self.frame_dim[3] = self.center_y + (self.screen_height / self.tile_size) / 2

    def homing(self):
        self.auto_home = True

    def add_homing_btn(self):
        icon = Image.open("/usr/share/parth/media/gps-2.png")
        self.frame.paste(icon, (self.screen_width - 75, self.screen_height - 75))
        self.home_btn_bbox = (self.screen_width - 75, self.screen_height - 75, self.screen_width, self.screen_height)

    def update_loc(self):
        draw = ImageDraw.Draw(self.frame)
        text = id
        square_size = 20
        my_loc = self.my_loc
        if round((my_loc[0] - self.target_nav[0]) * 1000) == 0 and round((my_loc[1] - self.target_nav[1]) * 1000) == 0:
            if len(self.navlst)>0:
                self.navigating = True
                self.target_nav = self.navlst[0]
                self.navlst.pop(0)
            else:
                self.navigating = False
        # print(f"my loc: {my_loc}")
        # print(f"frame size: {self.frame_dim}")
        x, y = deg2num(my_loc[0], my_loc[1])
        # print("x, y: ", x,y)
        x -= self.frame_dim[0]
        x *= self.tile_size
        y -= self.frame_dim[2]
        y *= self.tile_size
        # print("x, y: ", x,y)
        square_top_left = (x, y)  # (x, y) coordinates of the top-left corner
        square_bottom_right = (square_top_left[0] + square_size, square_top_left[1] + square_size)

        # Draw the square
        draw.rectangle([square_top_left, square_bottom_right], outline="black", fill="blue")
        # Add text below the square
        font = ImageFont.truetype(font="/usr/share/parth/media/Arial.ttf", size=20)  # Use the default font
        text_position = (square_top_left[0], square_bottom_right[1] + 10)  # 10 pixels below the square
        draw.text(text_position, text, fill="white", font=font)

    def update_team_loc(self):
        team_loc = get_team_loc()
        for loc in team_loc:
            draw = ImageDraw.Draw(self.frame)
            text = loc[0]
            square_size = 20
            # print(f"my loc: {loc}")
            # print(f"frame size: {self.frame_dim}")
            x, y = deg2num(loc[1], loc[2])
            # print("x, y: ", x,y)
            x -= self.frame_dim[0]
            x *= self.tile_size
            y -= self.frame_dim[2]
            y *= self.tile_size
            # print("x, y: ", x,y)
            square_top_left = (x, y)  # (x, y) coordinates of the top-left corner
            square_bottom_right = (square_top_left[0] + square_size, square_top_left[1] + square_size)

            # Draw the square
            draw.ellipse([square_top_left, square_bottom_right], outline="black", fill="blue")
            # Add text below the square
            font = ImageFont.truetype(font="/usr/share/parth/media/Arial.ttf", size=20)  # Use the default font
            text_position = (square_top_left[0], square_bottom_right[1] + 10)  # 10 pixels below the square
            draw.text(text_position, text, fill="white", font=font)

    def display_image(self):
        """
        Display the combined image in the QGraphicsScene.
        """
        self.scene.clear()
        # Convert PIL image to QImage
        qimage = QImage(self.frame.tobytes(), self.frame.width, self.frame.height, QImage.Format.Format_RGB888)
        pixmap = QPixmap.fromImage(qimage)

        # Add the pixmap to the scene
        self.scene.addPixmap(pixmap)

        # Set the scene rect to the size of the image
        self.scene.setSceneRect(10, 40, self.frame.width, self.frame.height)


    def initialize_map(self):
        print("initializing map called")
        for x in range(math.floor(self.frame_dim[0]), math.ceil(self.frame_dim[1])):
            for y in range(math.floor(self.frame_dim[2]), math.ceil(self.frame_dim[3])):
                tile_img = load_tile(x, y)

                if tile_img is None:
                    print(f"No image found x: {x} y: {y}")
                    continue
                if self.tile_size != 256:
                    tile_img = tile_img.resize((self.tile_size, self.tile_size))
                screen_x = max((x - self.frame_dim[0]) * self.tile_size, 0)
                screen_y = max((y - self.frame_dim[2]) * self.tile_size, 0)
                # if else ladder to laod border images partially.
                if x == math.floor(self.frame_dim[0]) and y == math.floor(self.frame_dim[2]):
                    img_start_x = (self.frame_dim[0] - math.floor(self.frame_dim[0])) * self.tile_size
                    img_start_y = (self.frame_dim[2] - math.floor(self.frame_dim[2])) * self.tile_size
                    # print(x, y, img_start_x, img_start_y)
                    tile_img = tile_img.crop((img_start_x, img_start_y, self.tile_size, self.tile_size))

                elif x == math.floor(self.frame_dim[0]):
                    img_start_x = (self.frame_dim[0] - math.floor(self.frame_dim[0])) * self.tile_size
                    img_start_y = 0
                    # print(x, y, img_start_x, img_start_y)
                    tile_img = tile_img.crop((img_start_x, img_start_y, self.tile_size, self.tile_size))


                elif y == math.floor(self.frame_dim[2]):
                    img_start_x = 0
                    img_start_y = (self.frame_dim[2] - math.floor(self.frame_dim[2])) * self.tile_size
                    # print(x, y, img_start_x, img_start_y)
                    tile_img = tile_img.crop((img_start_x, img_start_y, self.tile_size, self.tile_size))

                self.map.paste(tile_img, (int(screen_x), int(screen_y)))
                print("initialize_map")

    def partial_tile_load_x(self, x_range):
        """"
        Load the remaining tiles after copying one side.
        """
        for x in range(math.floor(x_range[0]), math.ceil(x_range[1])):
            for y in range(math.floor(self.frame_dim[2]), math.ceil(self.frame_dim[3])):
                tile_img = load_tile(x, y)

                if tile_img is None:
                    print(f"No image found x: {x} y: {y}")
                    continue
                if self.tile_size != 256:
                    tile_img = tile_img.resize((self.tile_size, self.tile_size))
                screen_x = max((x - self.frame_dim[0]) * self.tile_size, 0)
                screen_y = max((y - self.frame_dim[2]) * self.tile_size, 0)
                # if else ladder to laod border images partially.
                if x == math.floor(self.frame_dim[0]) and y == math.floor(self.frame_dim[2]):
                    img_start_x = (self.frame_dim[0] - math.floor(self.frame_dim[0])) * self.tile_size
                    img_start_y = (self.frame_dim[2] - math.floor(self.frame_dim[2])) * self.tile_size
                    # print(x, y, img_start_x, img_start_y)
                    tile_img = tile_img.crop((img_start_x, img_start_y, self.tile_size, self.tile_size))

                elif x == math.floor(self.frame_dim[0]):
                    img_start_x = (self.frame_dim[0] - math.floor(self.frame_dim[0])) * self.tile_size
                    img_start_y = 0
                    # print(x, y, img_start_x, img_start_y)
                    tile_img = tile_img.crop((img_start_x, img_start_y, self.tile_size, self.tile_size))


                elif y == math.floor(self.frame_dim[2]):
                    img_start_x = 0
                    img_start_y = (self.frame_dim[2] - math.floor(self.frame_dim[2])) * self.tile_size
                    # print(x, y, img_start_x, img_start_y)
                    tile_img = tile_img.crop((img_start_x, img_start_y, self.tile_size, self.tile_size))

                self.map.paste(tile_img, (int(screen_x), int(screen_y)))

    def partial_tile_load_y(self, y_range):
        """"
        Load the remaining tiles after copying one side.
        """
        for x in range(math.floor(self.frame_dim[0]), math.ceil(self.frame_dim[1])):
            for y in range(math.floor(y_range[0]), math.ceil(y_range[1])):
                tile_img = load_tile(x, y)

                if tile_img is None:
                    print(f"No image found x: {x} y: {y}")
                    continue
                if self.tile_size != 256:
                    tile_img = tile_img.resize((self.tile_size, self.tile_size))
                screen_x = max((x - self.frame_dim[0]) * self.tile_size, 0)
                screen_y = max((y - self.frame_dim[2]) * self.tile_size, 0)
                # if else ladder to laod border images partially.
                if x == math.floor(self.frame_dim[0]) and y == math.floor(self.frame_dim[2]):
                    img_start_x = (self.frame_dim[0] - math.floor(self.frame_dim[0])) * self.tile_size
                    img_start_y = (self.frame_dim[2] - math.floor(self.frame_dim[2])) * self.tile_size
                    # print(x, y, img_start_x, img_start_y)
                    tile_img = tile_img.crop((img_start_x, img_start_y, self.tile_size, self.tile_size))

                elif x == math.floor(self.frame_dim[0]):
                    img_start_x = (self.frame_dim[0] - math.floor(self.frame_dim[0])) * self.tile_size
                    img_start_y = 0
                    # print(x, y, img_start_x, img_start_y)
                    tile_img = tile_img.crop((img_start_x, img_start_y, self.tile_size, self.tile_size))


                elif y == math.floor(self.frame_dim[2]):
                    img_start_x = 0
                    img_start_y = (self.frame_dim[2] - math.floor(self.frame_dim[2])) * self.tile_size
                    # print(x, y, img_start_x, img_start_y)
                    tile_img = tile_img.crop((img_start_x, img_start_y, self.tile_size, self.tile_size))

                self.map.paste(tile_img, (int(screen_x), int(screen_y)))


    def merge_tiles(self):
        # Current frame dimensions: [x_min, x_max, y_min, y_max]
        curr_x_min, curr_x_max, curr_y_min, curr_y_max = self.frame_dim
        # Previous frame dimensions (use [0, 0, 0, 0] if None)
        prev_x_min, prev_x_max, prev_y_min, prev_y_max = self.frame_dim_prev

        crop_zone = [0,0,self.map.width, self.map.height]
        startx, starty = 0, 0
        x_range, y_range = [], []

        if curr_x_min < prev_x_min and prev_x_min < curr_x_max:
            crop_zone[2] = (curr_x_max - prev_x_min)*self.tile_size
            startx = (prev_x_min - curr_x_min)*self.tile_size
            x_range = [curr_x_min, prev_x_min]
        elif curr_x_min < prev_x_max and prev_x_max < curr_x_max:
            crop_zone[0] = (curr_x_min - prev_x_min)*self.tile_size
            x_range = [prev_x_max, curr_x_max]
        else:
            x_range = [self.frame_dim[0], self.frame_dim[1]]


        if curr_y_min < prev_y_min and prev_y_min < curr_y_max:
            crop_zone[3] = (curr_y_max - prev_y_min)*self.tile_size
            starty = (prev_y_min - curr_y_min)*self.tile_size
            y_range = [curr_y_min, prev_y_min]
        elif curr_y_min < prev_y_max and prev_y_max < curr_y_max:
            crop_zone[1] = (curr_y_min - prev_y_min)*self.tile_size
            y_range = [prev_y_max, curr_y_max]
        else:
            y_range = [self.frame_dim[2], self.frame_dim[3]]

        tile_img = self.map.crop(tuple(crop_zone))
        self.map.paste(tile_img, (int(startx), int(starty)))

        self.partial_tile_load_x(x_range)
        self.partial_tile_load_y(y_range)








    def update_loc_panel(self):
        draw = ImageDraw.Draw(self.frame)
        font = ImageFont.truetype(font="/usr/share/parth/media/Arial.ttf", size=20)  # Use the default font
        lat, lon = decimal_to_dm(self.my_loc[0]), decimal_to_dm(self.my_loc[1])
        e, n = deg2dsm(self.my_loc[0], self.my_loc[1])
        easting, northing = deg2grid(self.my_loc[0], self.my_loc[1])

        rect_bbox = (0, self.screen_height - 80, 300, self.screen_height)
        draw.rectangle(rect_bbox, fill="gray")

        text = f"Lat: {lat},   Lon: {lon}"
        text_position = (5, self.screen_height - 75)  # 10 pixels below the square
        draw.text(text_position, text, fill="white", font=font)
        text = f"DSM E: {e},   N: {n}"
        text_position = (5, self.screen_height - 50)  # 10 pixels below the square
        draw.text(text_position, text, fill="white", font=font)
        text = f"ESM E: {round(easting)} ,   N: {round(northing)}"
        text_position = (5, self.screen_height - 25)
        draw.text(text_position, text, fill="white", font=font)
        pass

    def add_nav_dir(self):
        if self.navigating:
            draw = ImageDraw.Draw(self.frame)
            font = ImageFont.truetype(font="/usr/share/parth/media/Arial.ttf", size=20)  # Use the default font
            # Define the arrow properties
            arrow_color = "red"  # Arrow color
            arrow_width = 5  # Arrow line width
            x, y = deg2num(self.my_loc[0], self.my_loc[1])
            x -= self.frame_dim[0]
            y -= self.frame_dim[2]
            start_point = (x * self.tile_size, y * self.tile_size)  # Start point of the arrow (x, y)
            text = str(haversine(self.my_loc[0], self.my_loc[1], self.target_nav[0], self.target_nav[1]))
            text_position = (start_point[0]+50, start_point[1]+50)
            draw.text(text_position, text, fill="white", font=font)
            x, y = deg2num(self.target_nav[0], self.target_nav[1])
            x -= self.frame_dim[0]
            y -= self.frame_dim[2]
            end_point = (x * self.tile_size, y * self.tile_size)  # End point of the arrow (x, y)
            arrowhead_size = 20  # Size of the arrowhead
            # Draw the arrow shaft (line)
            draw.line([start_point, end_point], fill=arrow_color, width=arrow_width)

            # Calculate the arrowhead points
            def calculate_arrowhead_points(start, end, size):
                """Calculate the points for the arrowhead."""
                from math import atan2, cos, sin, radians

                # Calculate the angle of the line
                angle = atan2(end[1] - start[1], end[0] - start[0])
                angle_deg = angle * 180 / 3.14159  # Convert radians to degrees

                # Calculate the arrowhead points
                x1 = end[0] - size * cos(radians(angle_deg + 30))
                y1 = end[1] - size * sin(radians(angle_deg + 30))
                x2 = end[0] - size * cos(radians(angle_deg - 30))
                y2 = end[1] - size * sin(radians(angle_deg - 30))

                return [(x1, y1), end_point, (x2, y2)]

            # Draw the arrowhead (triangle)
            arrowhead_points = calculate_arrowhead_points(start_point, end_point, arrowhead_size)
            draw.polygon(arrowhead_points, fill=arrow_color)



    def show_func_panel(self, mouse_pos):
        # Create the pop-up window
        popup = PopupWindow()
        self.droppin_x = mouse_pos.x() / self.tile_size + self.frame_dim[0]
        self.droppin_y = mouse_pos.y() / self.tile_size + self.frame_dim[2]
        print(self.droppin_x, self.droppin_y)
        self.droppin_x, self.droppin_y = num2deg(self.droppin_x, self.droppin_y)
        easting, northing = decimal_to_dm(self.droppin_x), decimal_to_dm(self.droppin_y)
        popup.label = QLabel(f"{easting}      |||     {northing}")
        # popup.label.setAlignment(Qt.AlignmentFlag.AlignCenter)
        popup.layout.addWidget(popup.label)
        easting, northing = deg2dsm(self.droppin_x, self.droppin_y)
        popup.label = QLabel(f"DSM:   {easting}      |||     {northing}")
        # popup.label.setAlignment(Qt.AlignmentFlag.AlignCentfer)
        popup.layout.addWidget(popup.label)
        cord = indiagrid.wgs84_to_igs(self.droppin_x, self.droppin_y)
        easting = round(cord["Easting"])
        northing = round(cord["Northing"])
        popup.label = QLabel(f"ESM:   {easting}      |||     {northing}")
        # popup.label.setAlignment(Qt.AlignmentFlag.AlignCenter)
        # add text
        popup.layout.addWidget(popup.label)
        popup.setWindowTitle("Options")
        # Add buttons
        popup.set_route_btn = QPushButton("Set Route")
        popup.stp_nav_btn = QPushButton("Stop navigation")
        popup.mk_enemybtn = QPushButton("Mark as enemy")
        popup.addwpbtn = QPushButton("Add Waypoint")
        popup.send_route_btn = QPushButton("Send as RV")
        popup.arty_btn = QPushButton("Arty Fire")
        popup.atk_btn = QPushButton("Atk Hepter")
        popup.settings_btn = QPushButton("Settings")

        #ocnverting alternate btn grey
        popup.set_route_btn.setStyleSheet("background-color: gray;")
        popup.mk_enemybtn.setStyleSheet("background-color: gray;")
        popup.send_route_btn.setStyleSheet("background-color: gray;")
        popup.atk_btn.setStyleSheet("background-color: gray;")

        # connect the buttons to functinos
        popup.set_route_btn.clicked.connect(partial(self.set_route, popup))
        popup.stp_nav_btn.clicked.connect(partial(self.stp_nav, popup))
        popup.mk_enemybtn.clicked.connect(partial(self.mkenemy, popup))
        popup.addwpbtn.clicked.connect(partial(self.addwpmenu, popup))
        popup.send_route_btn.clicked.connect(partial(self.send_route_panel, popup))
        popup.arty_btn.clicked.connect(partial(self.atry_fire, popup))
        popup.atk_btn.clicked.connect(partial(self.atk_hep, popup))
        popup.settings_btn.clicked.connect(partial(self.settings, popup))


        # show buttons
        popup.layout.addWidget(popup.set_route_btn)
        popup.layout.addWidget(popup.stp_nav_btn)
        popup.layout.addWidget(popup.mk_enemybtn)
        popup.layout.addWidget(popup.addwpbtn)
        popup.layout.addWidget(popup.send_route_btn)
        popup.layout.addWidget(popup.arty_btn)
        popup.layout.addWidget(popup.atk_btn)
        popup.layout.addWidget(popup.settings_btn)
        popup.exec()
        # self.panel_layout.addWidget(self.panel_label)
        # self.panel.setVisible(self.panel_visiblity)

    def stp_nav(self, panel):
        panel.close()
        window.navlst = []
        window.navigating = False

    def set_route(self, panel):
        panel.close()
        self.target_nav = (self.droppin_x, self.droppin_y)
        self.navigating = True

    def mkenemy(self, panel):
        panel.close()
        self.selectEnemy = BaseWindow()
        self.selectEnemy.setWindowTitle("Select The type of enemy")
        self.selectEnemy.layout.addWidget(QLabel("Select the type of enemy: "))
        btnLst = [
            "En Tk/LAT/HAT",
            "En Inf Dply",
            "En Arty/Mor"
        ]
        for btnName in btnLst:
            btn = QPushButton(btnName)
            btn.clicked.connect(partial(self.showEn, btnName))
            self.selectEnemy.layout.addWidget(btn)
        self.selectEnemy.show()

    def showEn(self, enType):
        lat, lon = deg2num(self.droppin_x, self.droppin_y)
        t = time.time()
        self.enPos[t] = [enType, lat, lon]
        msg = f"e:{enType}:{round(self.droppin_x, 4)}:{round(self.droppin_y,4)}:{round(t, 4)};"
        query = "INSERT IGNORE INTO sendLst VALUES (%s);"
        params = (msg,)
        execWriteSql("serial", query, params)
        self.selectEnemy.close()




    def addwpmenu(self, panel):
        f = open("/usr/share/parth/routes.pkl", "rb")
        data = pickle.load(f)
        f.close()
        self.routes = BaseWindow()
        for route in data.keys():
            btn = QPushButton(route)
            btn.clicked.connect(partial(self.addwp, data, route))
            self.routes.layout.addWidget(btn)

        self.routes.show()
        panel.close()

    def addwp(self, data, routename):
        row = int(len(list(data[routename].keys())))+1
        data[routename][str(row)]=[self.droppin_x, self.droppin_y]
        f = open("/usr/share/parth/routes.pkl", "wb")
        pickle.dump(data, f)
        f.close()
        self.routes.close()


    def send_route_panel(self, panel):
        panel.close()
        popup = PopupWindow()
        popup.setWindowTitle("Select TKs to send route to")
        popup.setGeometry(300, 300, 300, 300)
        team = get_team_loc()
        chk_box = []
        for i, tk in enumerate(team):
            bt = QCheckBox(tk[0])
            chk_box.append(bt)
            chk_box[i].stateChanged.connect(partial(self.send_route, chk_box[i]))
            popup.layout.addWidget(chk_box[i])
        chk_box.append(QCheckBox("All"))
        chk_box[-1].stateChanged.connect(partial(self.send_route, chk_box[-1]))
        popup.layout.addWidget(chk_box[-1])

        btn = QPushButton("Send")
        btn.clicked.connect(partial(popup.close))
        popup.layout.addWidget(btn)
        popup.exec()

    def send_route(self, chk_box, t):
        if chk_box.isChecked():
            logging.error("saving rounte}")
            conn = mysql.connector.connect(
                database="serial",
                user="radio",
                password="System@68",
                host='localhost',
                auth_plugin='mysql_native_password',
            )
            cur = conn.cursor()
            try:
                cur.execute("INSERT INTO serial.sendLst VALUES (%s);", (f"w:{chk_box.text()}:{round(self.droppin_x, 4)}:{round(self.droppin_y, 4)}:{round(time.time(),4)};",))
                conn.commit()
                cur.close()
                conn.close()
            except Exception as e:
                raise ValueError(e)

    def chk_rxcv_route(self):
        querry = "select * from rcvLst;"
        msgLst = execReadSql("serial", querry)
        if msgLst is None:
            return
        for msg in msgLst:
            try:
                logging.error(msg)
                if msg.startswith("w:"):
                    data = msg.split(":")
                    lat = float(data[2])
                    lon = float(data[3])
                    self.navigating = True
                    self.target_nav = (lat, lon)

                else:
                    logging.error(msg)
                    data = msg.split(":")
                    enType = data[1]
                    lat = float(data[2])
                    lon = float(data[3])
                    t = float(data[4])
                    lat, lon = deg2num(lat, lon)
                    self.enPos[t] = [enType, lat, lon]
            except Exception as e:
                logging.error(e)
            finally:
                querry = "DELETE FROM rcvLst WHERE id=%s"
                params = (msg,)
                execWriteSql("serial", querry, params)


    def atry_fire(self, popup):
        popup.close()
        popup = PopupWindow()
        popup.timer.stop()
        popup.setWindowTitle("Arty Fire Procedure")
        easting, northing = deg2grid(self.my_loc[0], self.my_loc[1])
        easting = round(easting, 2)
        northing = round(northing, 2)
        dist, bearing = get_distance_and_bearing(self.my_loc[0], self.my_loc[1], self.droppin_x, self.droppin_y)
        bearing = int(bearing)
        dist = int(dist) + float(int((dist - (dist)) * 10)) / 10
        lst = [
            f"{id} for 16B tgt over",
            f"16B for {id} tgt over",
            f"{id} for 16B GR {northing}, {easting}, OT {bearing} deg, distance {dist}m (description) over",
            f"16B for {id} GR {northing}, {easting}, OT {bearing} deg, distance {dist}m (description) waitout",
            f"16B to {id} tgt identified over",
            f"{id} for 16B tgt identified out",
            f"16B to {id} Shot out flight 20 sec over",
            f"{id} for 16B Shot out flight 20 sec out",
            f"{id} for 16B Add ___ left/right ___ over",
            f"{id} for 16B Add ___ left/right ___ over",
            f"16B to {id} Shot out flight 20 sec over",
            f"{id} for 16B Shot out flight 20 sec out",
            f"{id} for 16B Shot on tgt neutralize for 5 miniutes over",
            f"16B for {id} Shot on tgt neutralize for 5 miniutes out",
        ]
        popup.layout.setSpacing(10)
        popup.layout.setContentsMargins(10, 10, 10, 10)
        for i in lst:
            label = QLabel()
            if i.startswith("16B for ") or i.startswith("16B to "):
                label.setStyleSheet("QLabel { background-color: rgb(200,100,100); }")
                i = f"16B:  {i}"
            else:
                i = f"{id}:  {i}"
            label.setText(i)
            label.setWordWrap(True)
            label.setSizePolicy(label.sizePolicy().horizontalPolicy(), label.sizePolicy().verticalPolicy())
            popup.setMinimumSize(700, 700)
            popup.layout.addWidget(label)
        popup.exec()


    def atk_hep(self, popup):
        popup.close()
        popup = PopupWindow()
        popup.timer.stop()
        popup.setWindowTitle("Arty Fire Procedure")
        dist, bearing = get_distance_and_bearing(self.my_loc[0], self.my_loc[1], self.droppin_x, self.droppin_y)
        bearing = int(bearing)
        dist = int(dist) + float(int((dist - (dist))*10))/10
        lat , lon = decimal_to_dm(self.my_loc[0]), decimal_to_dm(self.my_loc[1])
        lst = [
            f"{id} for Rudra radio check",
            f"Rudra for {id} Reading now, How do you read me",
            f"{id} for Rudra Reading now",
            f"{id} for Rudra Own loc {lat}N, {lon}E",
            f"Rudra to {id} your loc {lat}N, {lon}E",
            f"{id} for Rudra Confirm when ready to note TGT",
            f"Rudra to {id} Ready to note TGT",
            f"{id} for Rudra Ref to own loc bearing {bearing} deg, dist {dist} m (description)",
            f"Rudra to {id} Ref to your loc bearing {bearing} deg, dist {dist} m (description)",
            f"{id} to Rudra FLOT (desc to ref elements)",
            f"{id} to Rudra confirm TOT",
            f"Rudra to {id} time to TOT __",
            f"{id} to Rudra Roger, Out"
        ]
        popup.layout.setSpacing(10)
        popup.layout.setContentsMargins(10, 10, 10, 10)
        for i in lst:
            label = QLabel()
            if i.startswith("Rudra for ") or i.startswith("Rudra to "):
                label.setStyleSheet("QLabel { background-color: rgb(200,100,100); }")
                i = f"Rudra:  {i}"
            else:
                i = f"{id}:  {i}"
            label.setText(i)
            label.setWordWrap(True)
            label.setSizePolicy(label.sizePolicy().horizontalPolicy(), label.sizePolicy().verticalPolicy())
            popup.setMinimumSize(700, 700)
            popup.layout.addWidget(label)
        popup.exec()


    def zoomIn(self):
        print("zooming in ", self.tile_size)
        self.tile_size_prev = self.tile_size
        self.tile_size = int(self.tile_size*2)

    def zoomOut(self):
        self.tile_size_prev = self.tile_size
        self.tile_size = int(self.tile_size/2)

    def settings(self, panel):
        panel.close()
        popup = PopupWindow()
        popup.dropdown = QComboBox()
        popup.savebtn = QPushButton("Save")
        popup.dropdown.addItems(["68", "A", "B", "C", "A1", "A2", "A3", "A4", "B1", "B2", "B3", "B4", "C1", "C2", "C3", "C4"])
        # popup.dropdown.currentIndexChanged.connect(partial(self.nameChange, popup))
        popup.savebtn.clicked.connect(partial(self.nameChange, popup))
        popup.layout.addWidget(popup.dropdown)
        popup.layout.addWidget(popup.savebtn)
        popup.exec()

    def nameChange(self, panel):
        config["host"]["id"] = panel.dropdown.currentText()
        panel.close()
        with open("/etc/parth/parth.conf", "w") as configfile:
            config.write(configfile)
        with open("/usr/share/parth/restart.txt", "w") as f:
            f.write("True")

    def navigate(self):
        print("btn pressed")
        self.navman = NavigMenu()

        self.navman.show()

    def add_zoom_btn(self):
        icon = Image.open("/usr/share/parth/media/zoomOut.png")
        self.frame.paste(icon, (self.screen_width - 75, self.screen_height - 150))
        icon = Image.open("/usr/share/parth/media/zoomIn.png")
        self.frame.paste(icon, (self.screen_width - 75, self.screen_height - 225))
        icon = Image.open("/usr/share/parth/media/navigate.jpg")
        self.frame.paste(icon, (self.screen_width - 75, self.screen_height - 300))


    def addEnmk(self):
        for t in self.enPos.keys():
            en = self.enPos[t][0]
            x, y = self.enPos[t][1], self.enPos[t][2]
            if time.time()- t > 900:
                self.enPos.pop(t)
                return

            text = en

            # pt calc for the icon
            x = (x-self.frame_dim[0])*self.tile_size
            y = (y-self.frame_dim[2])*self.tile_size


            draw = ImageDraw.Draw(self.frame)
            size = 20
            h = (3 ** 0.5 / 2) * size  # height of the triangle

            # Calculate the vertices of the equilateral triangle
            p1 = (x, y - (2 / 3) * h)  # top vertex
            p2 = (x - size / 2, y + h / 3)  # bottom-left
            p3 = (x + size / 2, y + h / 3)  # bottom-right

            draw.polygon([p1, p2, p3], fill="red")
            font = ImageFont.truetype(font="/usr/share/parth/media/Arial.ttf", size=20)  # Use the default font
            text_position = (x, y + 14)  # 10 pixels below the square
            draw.text(text_position, text, fill="white", font=font)


    def main(self):
        # print(self.frame_dim)
        self.my_loc = get_loc()
        self.update_viewport()
        self.merge_tiles()
        self.chk_rxcv_route()
        self.frame = self.map.copy()
        self.update_loc()
        self.update_team_loc()
        self.add_homing_btn()
        self.update_loc_panel()
        self.addEnmk()
        self.add_nav_dir()
        self.add_zoom_btn()
        self.display_image()


if __name__ == "__main__":
    # Create the application object
    app = QApplication(sys.argv)

    password_dialog = PasswordDialog()


    # When authentication succeeds:
    def show_second():
        global window
    window = MyApp()


    # password_dialog.authenticated.connect(show_second)
    # password_dialog.show()

    sys.exit(app.exec())

