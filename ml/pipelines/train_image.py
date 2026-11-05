import torch
import torch.nn as nn
import torch.optim as optim
from torchvision import datasets, transforms, models
import os

print("Training Image Classifier (MobileNetV3) on Urban Issues dataset...")
data_dir = "data/raw/images/complaints/urban_issues"

device = torch.device("mps" if torch.backends.mps.is_available() else "cpu")
print(f"Using device: {device}")

# CRITICAL FIX: Added Normalize
transform = transforms.Compose([
    transforms.Resize((224, 224)),
    transforms.ToTensor(),
    transforms.Normalize(mean=[0.485, 0.456, 0.406], std=[0.229, 0.224, 0.225])
])

dataset = datasets.ImageFolder(root=data_dir, transform=transform)
# Use 3000 images for better learning
subset_indices = torch.arange(min(3000, len(dataset)))
dataset = torch.utils.data.Subset(dataset, subset_indices)

dataloader = torch.utils.data.DataLoader(dataset, batch_size=32, shuffle=True)
num_classes = len(dataset.dataset.classes)

model = models.mobilenet_v3_small(weights='DEFAULT')
model.classifier[3] = nn.Linear(model.classifier[3].in_features, num_classes)
model = model.to(device)

criterion = nn.CrossEntropyLoss()
optimizer = optim.Adam(model.parameters(), lr=0.0005)

model.train()
for epoch in range(3): # Train for 3 epochs
    print(f"--- Epoch {epoch+1}/3 ---")
    running_loss = 0.0
    for batch_idx, (inputs, labels) in enumerate(dataloader):
        inputs, labels = inputs.to(device), labels.to(device)
        optimizer.zero_grad()
        outputs = model(inputs)
        loss = criterion(outputs, labels)
        loss.backward()
        optimizer.step()
        running_loss += loss.item()
        if batch_idx % 20 == 0:
            print(f"Batch {batch_idx}/{len(dataloader)} - Loss: {loss.item():.4f}")

os.makedirs("ml/models", exist_ok=True)
torch.save(model.state_dict(), "ml/models/civic_classifier.pt")
print("Model successfully trained and saved.")
