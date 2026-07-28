
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "          Thai Speech-to-Text Server"



if ! command -v python3 &> /dev/null; then
    echo -e "${RED}[ERROR]${NC} Python3 not found!"
    echo "Please install Python3 from https://www.python.org"
    exit 1
fi

echo -e "${GREEN}[OK]${NC} Python3 found"
echo ""

if [ ! -f "app.py" ]; then
    echo -e "${RED}[ERROR]${NC} app.py not found in current directory!"
    echo "Please make sure you're in the correct folder."
    exit 1
fi

echo -e "${GREEN}[OK]${NC} Server file found"
echo ""

# ตรวจสอบและติดตั้ง dependencies
echo "Checking dependencies..."
if ! python3 -c "import flask" &> /dev/null; then
    echo -e "${YELLOW}[INSTALLING]${NC} Installing required packages..."
    pip3 install flask flask-cors torch transformers soundfile librosa numpy
    
    if [ $? -ne 0 ]; then
        echo -e "${RED}[ERROR]${NC} Failed to install packages"
        exit 1
    fi
    
    echo -e "${GREEN}[OK]${NC} Packages installed successfully"
    echo ""
fi

# ตรวจสอบ ffmpeg (optional แต่แนะนำ)
if ! command -v ffmpeg &> /dev/null; then
    echo -e "${YELLOW}[WARNING]${NC} ffmpeg not found (optional but recommended)"
    echo "Install it with:"
    echo "  Mac:   brew install ffmpeg"
    echo "  Linux: sudo apt-get install ffmpeg"
    echo ""
fi

echo "============================================================"
echo "                   Starting Server..."
echo "============================================================"
echo ""
echo "Press Ctrl+C to stop the server"
echo ""

# รัน server
python3 app.py

echo ""
echo "Server stopped."
