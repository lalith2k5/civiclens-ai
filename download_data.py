import os
import urllib.request

print("Downloading required datasets (India Flood Inventory)...")

# Create directory
os.makedirs("data/raw/context/flood", exist_ok=True)

# Download Flood CSV
url = "https://zenodo.org/records/16994648/files/India_Flood_Inventory_v3.csv?download=1"
dest = "data/raw/context/flood/India_Flood_Inventory_v3.csv"

try:
    urllib.request.urlretrieve(url, dest)
    print(f"✅ Successfully downloaded Flood Inventory to {dest}")
except Exception as e:
    print(f"❌ Failed to download dataset: {e}")

print("\nNote: The 4.5GB Image Dataset is NOT downloaded here.")
print("The pre-trained models in ml/models/ are already included in the repo.")
print("You only need the image dataset if you want to re-train the AI from scratch.")
