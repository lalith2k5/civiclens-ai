import pandas as pd
import glob
from sklearn.ensemble import RandomForestRegressor
from sklearn.model_selection import train_test_split
from sklearn.metrics import mean_absolute_error
import joblib
import os

print("Training Resolution-Time Model on BMC Mumbai dataset...")
# Find the BMC CSV
csv_files = glob.glob("data/raw/complaints/bmc/*.csv")
if not csv_files:
    print("BMC dataset not found. Creating a fallback model.")
    # Fallback if download was incomplete
    X = pd.DataFrame({'category_code': [0,1,2,3,4]*100})
    y = [5, 10, 2, 3, 7] * 100
else:
    df = pd.read_csv(csv_files[0])
    # Keep only resolved complaints with valid times
    df = df.dropna(subset=['resolution_days', 'complaint_category'])
    # Encode category
    df['category_code'] = df['complaint_category'].astype('category').cat.codes
    X = df[['category_code']]
    y = df['resolution_days']

X_train, X_test, y_train, y_test = train_test_split(X, y, test_size=0.2, random_state=42)
model = RandomForestRegressor(n_estimators=100, max_depth=10, random_state=42)
model.fit(X_train, y_train)

preds = model.predict(X_test)
print(f"Model trained. MAE: {mean_absolute_error(y_test, preds):.2f} days")

os.makedirs("ml/models", exist_ok=True)
joblib.dump(model, "ml/models/resolution_rf.joblib")
print("Saved to ml/models/resolution_rf.joblib")
