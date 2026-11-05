import torch
import torch.nn as nn
import torch.optim as optim
from torchvision import datasets, transforms, models
import os

print("Training Image Classifier (MobileNetV3) on Urban Issues dataset...")
data_dir = "data/raw/images/complaints/urban_issues"

if not os.path.exists(data_dir):
    print(f"Image dataset not found at {data_dir}. Skipping training.")
    exit(0)

# Detect device (M2 MPS or CPU)
device = torch.device("mps" if torch.backends.mps.is_available() else "cpu")
print(f"Using device: {device}")

transform = transforms.Compose([
    transforms.Resize((224, 224)),
    transforms.ToTensor(),
])

# Use ImageFolder
try:
    dataset = datasets.ImageFolder(root=data_dir, transform=transform)
    # Limit dataset to 500 images for fast terminal demo (change to full for production)
    subset_indices = torch.arange(min(500, len(dataset)))
    dataset = torch.utils.data.Subset(dataset, subset_indices)
    
    dataloader = torch.utils.data.DataLoader(dataset, batch_size=16, shuffle=True)
    num_classes = len(dataset.dataset.classes)
    print(f"Found {num_classes} classes. Training on {len(dataset)} images for 1 epoch.")
    
    model = models.mobilenet_v3_small(weights='DEFAULT')
    model.classifier[3] = nn.Linear(model.classifier[3].in_features, num_classes)
    model = model.to(device)
    
    criterion = nn.CrossEntropyLoss()
    optimizer = optim.Adam(model.parameters(), lr=0.001)
    
    model.train()
    for batch_idx, (inputs, labels) in enumerate(dataloader):
        inputs, labels = inputs.to(device), labels.to(device)
        optimizer.zero_grad()
        outputs = model(inputs)
        loss = criterion(outputs, labels)
        loss.backward()
        optimizer.step()
        if batch_idx % 5 == 0:
            print(f"Batch {batch_idx}/{len(dataloader)} - Loss: {loss.item():.4f}")

    os.makedirs("ml/models", exist_ok=True)
    torch.save(model.state_dict(), "ml/models/civic_classifier.pt")
    print("Saved to ml/models/civic_classifier.pt")
except Exception as e:
    print(f"Error during image training: {e}")
