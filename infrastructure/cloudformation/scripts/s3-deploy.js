const { S3Client, PutObjectCommand, DeleteObjectCommand, ListObjectsV2Command } = require('@aws-sdk/client-s3');
const { CloudFrontClient, CreateInvalidationCommand } = require('@aws-sdk/client-cloudfront');
const { CloudFormationClient, DescribeStacksCommand } = require('@aws-sdk/client-cloudformation');
const fs = require('fs');
const path = require('path');
const mime = require('mime-types');

class FrontendDeployer {
  constructor() {
    this.s3Client = new S3Client({ region: process.env.AWS_REGION || 'us-east-1' });
    this.cloudFrontClient = new CloudFrontClient({ region: process.env.AWS_REGION || 'us-east-1' });
    this.cloudFormationClient = new CloudFormationClient({ region: process.env.AWS_REGION || 'us-east-1' });
    this.stackName = 'BirdWatchersEmporiumFrontendStack';
  }

  async getStackOutputs() {
    try {
      const command = new DescribeStacksCommand({ StackName: this.stackName });
      const response = await this.cloudFormationClient.send(command);
      const stack = response.Stacks[0];
      
      const outputs = {};
      stack.Outputs.forEach(output => {
        outputs[output.OutputKey] = output.OutputValue;
      });
      
      return outputs;
    } catch (error) {
      console.error('Error getting stack outputs:', error);
      throw error;
    }
  }

  async uploadFile(bucketName, filePath, key) {
    const fileContent = fs.readFileSync(filePath);
    const contentType = mime.lookup(filePath) || 'application/octet-stream';
    
    const command = new PutObjectCommand({
      Bucket: bucketName,
      Key: key,
      Body: fileContent,
      ContentType: contentType,
      CacheControl: this.getCacheControl(key)
    });

    await this.s3Client.send(command);
    console.log(`✅ Uploaded: ${key}`);
  }

  getCacheControl(key) {
    if (key.endsWith('.html')) {
      return 'no-cache, no-store, must-revalidate';
    } else if (key.match(/\.(js|css|png|jpg|jpeg|gif|ico|svg|woff|woff2|ttf|eot)$/)) {
      return 'public, max-age=31536000'; // 1 year
    }
    return 'public, max-age=3600'; // 1 hour
  }

  async deleteOldFiles(bucketName, newFiles) {
    try {
      const command = new ListObjectsV2Command({ Bucket: bucketName });
      const response = await this.s3Client.send(command);
      
      if (response.Contents) {
        for (const object of response.Contents) {
          if (!newFiles.includes(object.Key)) {
            const deleteCommand = new DeleteObjectCommand({
              Bucket: bucketName,
              Key: object.Key
            });
            await this.s3Client.send(deleteCommand);
            console.log(`🗑️  Deleted: ${object.Key}`);
          }
        }
      }
    } catch (error) {
      console.error('Error deleting old files:', error);
    }
  }

  async invalidateCloudFront(distributionId) {
    try {
      const command = new CreateInvalidationCommand({
        DistributionId: distributionId,
        InvalidationBatch: {
          Paths: {
            Quantity: 1,
            Items: ['/*']
          },
          CallerReference: `deployment-${Date.now()}`
        }
      });

      const response = await this.cloudFrontClient.send(command);
      console.log(`🔄 CloudFront invalidation created: ${response.Invalidation.Id}`);
    } catch (error) {
      console.error('Error creating CloudFront invalidation:', error);
    }
  }

  async deploy() {
    try {
      console.log('🚀 Starting frontend deployment...\n');

      // Get stack outputs
      console.log('🔍 Getting stack information...');
      const outputs = await this.getStackOutputs();
      const bucketName = outputs.BucketName;
      const distributionId = outputs.DistributionId;

      if (!bucketName) {
        throw new Error('Could not find bucket name in stack outputs');
      }

      console.log(`📦 Bucket: ${bucketName}`);
      console.log(`🌐 Distribution: ${distributionId}\n`);

      // Build frontend
      console.log('📦 Building frontend...');
      const { execSync } = require('child_process');
      execSync('npm run build', { 
        cwd: path.join(__dirname, '../../../frontend'),
        stdio: 'inherit' 
      });

      // Upload files
      console.log('\n📤 Uploading files to S3...');
      const distPath = path.join(__dirname, '../../../frontend/dist');
      const files = this.getAllFiles(distPath);
      const newFiles = [];

      for (const file of files) {
        const relativePath = path.relative(distPath, file);
        const key = relativePath.replace(/\\/g, '/'); // Normalize path separators
        newFiles.push(key);
        await this.uploadFile(bucketName, file, key);
      }

      // Delete old files
      console.log('\n🗑️  Cleaning up old files...');
      await this.deleteOldFiles(bucketName, newFiles);

      // Invalidate CloudFront
      if (distributionId) {
        console.log('\n🔄 Invalidating CloudFront cache...');
        await this.invalidateCloudFront(distributionId);
      }

      console.log('\n✅ Deployment completed successfully!');
      console.log(`🌐 Website URL: ${outputs.WebsiteUrl}`);

    } catch (error) {
      console.error('\n❌ Deployment failed:', error.message);
      process.exit(1);
    }
  }

  getAllFiles(dirPath, arrayOfFiles = []) {
    const files = fs.readdirSync(dirPath);

    files.forEach(file => {
      const fullPath = path.join(dirPath, file);
      if (fs.statSync(fullPath).isDirectory()) {
        arrayOfFiles = this.getAllFiles(fullPath, arrayOfFiles);
      } else {
        arrayOfFiles.push(fullPath);
      }
    });

    return arrayOfFiles;
  }
}

// Run deployment
const deployer = new FrontendDeployer();
deployer.deploy();
