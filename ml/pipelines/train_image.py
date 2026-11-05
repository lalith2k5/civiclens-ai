import torch
import torch.nn as nn
import torch.optim as optim
from torchvision import datasets, transforms, models
from torch.utils.data import DataLoader, random_split
import os

print("Preparing FULL Image Classifier Training (No limits)...")
data_dir = "data/raw/images/complaints/urban_issues"
device = torch.device("mps" if torch.backends.mps.is_available() else "cpu")

# Transformations with Augmentation
train_transform = transforms.Compose([
    transforms.Resize((224, 224)),
    transforms.RandomHorizontalFlip(),
    transforms.RandomRotation(15),
    transforms.ColorJitter(brightness=0.2, contrast=0.2),
    transforms.ToTensor(),
    transforms.Normalize(mean=[0.485, 0.456, 0.406], std=[0.229, 0.224, 0.225])
])

val_transform = transforms.Compose([
    transforms.Resize((224, 224)),
    transforms.ToTensor(),
    transforms.Normalize(mean=[0.485, 0.456, 0.406], std=[0.229, 0.224, 0.225])
])

print("Loading full dataset...")
full_dataset = datasets.ImageFolder(root=data_dir)
num_classes = len(full_dataset.classes)
print(f"Total images in dataset: {len(full_dataset)}")

# Split 80/20
train_size = int(0.8 * len(full_dataset))
val_size = len(full_dataset) - train_size
train_dataset, val_dataset = random_split(full_dataset, [train_size, val_size])

# Apply transforms manually to the subsets
class SubsetWithTransform(torch.utils.data.Dataset):
    def __init__(self, subset, transform=None):
        self.subset = subset
        self.transform = transform
    def __getitem__(self, index):
        x, y = self.subset[index]
        if self.transform: x = self.transform(x)
        return x, y
    def __len__(self):
        return len(self.subset)

train_dataset = SubsetWithTransform(train_dataset, train_transform)
val_dataset = SubsetWithTransform(val_dataset, val_transform)

train_loader = DataLoader(train_dataset, batch_size=64, shuffle=True)
val_loader = DataLoader(val_dataset, batch_size=64, shuffle=False)

print(f"Classes: {full_dataset.classes}")

model = models.mobilenet_v3_small(weights='DEFAULT')
model.classifier[3] = nn.Linear(model.classifier[3].in_features, num_classes)
model = model.to(device)

criterion = nn.CrossEntropyLoss()
optimizer = optim.Adam(model.parameters(), lr=0.001)
epochs = 5 # Full training

print("--- Starting FULL Training (This will take 20-30 mins) ---")
best_val_acc = 0.0

for epoch in range(epochs):
    model.train()
    running_loss = 0.0
    for i, (inputs, labels) in enumerate(train_loader):
        inputs, labels = inputs.to(device), labels.to(device)
        optimizer.zero_grad()
        outputs = model(inputs)
        loss = criterion(outputs, labels)
        loss.backward()
        optimizer.step()
        running_loss += loss.item()
        if i % 50 == 0:
            print(f"Epoch {epoch+1}, Batch {i}/{len(train_loader)}, Loss: {loss.item():.4f}")
        
    train_loss = running_loss / len(train_loader)
    
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
    
    if val_acc > best_val_acc:
        best_val_acc = val_acc
        os.makedirs("ml/models", exist_ok=True)
        torch.save(model.state_dict(), "ml/models/civic_classifier.pt")

print(f"Training Complete. Best Validation Accuracy: {best_val_acc:.2f}%")
