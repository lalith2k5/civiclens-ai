#!/bin/bash
set -e

cd ~/Desktop/civiclens-ai
source .venv/bin/activate

echo "Writing robust training script..."
cat > ml/pipelines/train_image.py << 'EOF'
import torch
import torch.nn as nn
import torch.optim as optim
from torchvision import datasets, transforms, models
from torch.utils.data import DataLoader, random_split, Subset
import os
import random

print("Preparing REAL Image Classifier (Balanced Sampling + Validation)...")
data_dir = "data/raw/images/complaints/urban_issues"
device = torch.device("mps" if torch.backends.mps.is_available() else "cpu")

# 1. Load full dataset to get class distribution
base_dataset = datasets.ImageFolder(root=data_dir)
classes = base_dataset.classes
print(f"Found {len(classes)} classes: {classes}")

# 2. Fix the bug: Balance the dataset manually
# We will take a max of 250 images per class to keep training under 15 mins
max_per_class = 250
class_counts = {i: 0 for i in range(len(classes))}
selected_indices = []

for idx, (path, label) in enumerate(base_dataset.samples):
    if class_counts[label] < max_per_class:
        selected_indices.append(idx)
        class_counts[label] += 1

# Shuffle the selected indices so classes are mixed
random.seed(42)
random.shuffle(selected_indices)
print(f"Balanced subset created with {len(selected_indices)} total images.")

# 3. Transformations
train_transform = transforms.Compose([
    transforms.Resize((224, 224)),
    transforms.RandomHorizontalFlip(),
    transforms.RandomRotation(10),
    transforms.ColorJitter(brightness=0.2, contrast=0.2),
    transforms.ToTensor(),
    transforms.Normalize(mean=[0.485, 0.456, 0.406], std=[0.229, 0.224, 0.225])
])

val_transform = transforms.Compose([
    transforms.Resize((224, 224)),
    transforms.ToTensor(),
    transforms.Normalize(mean=[0.485, 0.456, 0.406], std=[0.229, 0.224, 0.225])
])

# Split indices into 80% train, 20% val
split_idx = int(len(selected_indices) * 0.8)
train_indices = selected_indices[:split_idx]
val_indices = selected_indices[split_idx:]

# Create datasets using Subset with specific transforms
class TransformedSubset(torch.utils.data.Dataset):
    def __init__(self, dataset, indices, transform):
        self.dataset = dataset
        self.indices = indices
        self.transform = transform
    def __len__(self):
        return len(self.indices)
    def __getitem__(self, idx):
        img, label = self.dataset[self.indices[idx]]
        return self.transform(img), label

train_dataset = TransformedSubset(base_dataset, train_indices, train_transform)
val_dataset = TransformedSubset(base_dataset, val_indices, val_transform)

train_loader = DataLoader(train_dataset, batch_size=32, shuffle=True)
val_loader = DataLoader(val_dataset, batch_size=32, shuffle=False)

# 4. Setup Model
model = models.mobilenet_v3_small(weights='DEFAULT')
model.classifier[3] = nn.Linear(model.classifier[3].in_features, len(classes))
model = model.to(device)

criterion = nn.CrossEntropyLoss()
optimizer = optim.Adam(model.parameters(), lr=0.001)
epochs = 5

# 5. Real Training Loop with Validation
print("--- Starting Real Training ---")
best_val_acc = 0.0

for epoch in range(epochs):
    # Training Phase
    model.train()
    running_loss = 0.0
    for inputs, labels in train_loader:
        inputs, labels = inputs.to(device), labels.to(device)
        optimizer.zero_grad()
        outputs = model(inputs)
        loss = criterion(outputs, labels)
        loss.backward()
        optimizer.step()
        running_loss += loss.item()
        
    train_loss = running_loss / len(train_loader)
    
    # Validation Phase
    model.eval()
    correct = 0
    total = 0
    with torch.no_grad():
        for inputs, labels in val_loader:
            inputs, labels = inputs.to(device), labels.to(device)
            outputs = model(inputs)
            _, predicted = torch.max(outputs.data, 1)
            total += labels.size(0)
            correct += (predicted == labels).sum().item()
            
    val_acc = 100 * correct / total
    print(f"Epoch [{epoch+1}/{epochs}] - Train Loss: {train_loss:.4f} - Val Accuracy: {val_acc:.2f}%")
    
    # Save the best model only
    if val_acc > best_val_acc:
        best_val_acc = val_acc
        os.makedirs("ml/models", exist_ok=True)
        torch.save(model.state_dict(), "ml/models/civic_classifier.pt")

print(f"Training Complete. Best Validation Accuracy: {best_val_acc:.2f}%")
EOF

echo "Executing real training (this will take 10-15 minutes)..."
python ml/pipelines/train_image.py

echo "Updating API to keep classes in sync..."
python -c "
import os, json
data_dir = 'data/raw/images/complaints/urban_issues'
classes = sorted([d for d in os.listdir(data_dir) if os.path.isdir(os.path.join(data_dir, d))])
with open('ml/models/classes.json', 'w') as f:
    json.dump(classes, f)
"

git add .
git commit -m "feat(ml): implement balanced dataset, train/val split, augmentation, and real metrics"
git push -u origin main

cd ~/Desktop/civiclens-ai-handoff
zip -qr handoff.zip .

echo "============================================================"
echo "REAL AI Training Complete!"
echo "============================================================"
