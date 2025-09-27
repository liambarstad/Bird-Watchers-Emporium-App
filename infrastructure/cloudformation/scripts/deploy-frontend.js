const { execSync } = require('child_process');
const path = require('path');
const fs = require('fs');

console.log('🚀 Deploying Frontend to S3...\n');

try {
  // Build the frontend
  console.log('📦 Building frontend...');
  execSync('npm run build', { 
    cwd: path.join(__dirname, '../../../frontend'),
    stdio: 'inherit' 
  });

  // Get stack outputs to find the bucket name
  console.log('\n🔍 Getting stack outputs...');
  const outputs = execSync('cdk list --long', {
    cwd: __dirname,
    encoding: 'utf8'
  });

  // For now, we'll use a simple approach - you can enhance this to parse actual outputs
  const bucketName = process.env.BUCKET_NAME || 'bird-watchers-emporium-frontend';
  
  console.log(`\n📤 Uploading to S3 bucket: ${bucketName}`);
  
  // Sync the built files to S3
  execSync(`aws s3 sync ../../../frontend/dist s3://${bucketName} --delete`, {
    stdio: 'inherit'
  });

  // Invalidate CloudFront cache
  console.log('\n🔄 Invalidating CloudFront cache...');
  execSync('aws cloudfront create-invalidation --distribution-id $(aws cloudformation describe-stacks --stack-name BirdWatchersEmporiumFrontendStack --query "Stacks[0].Outputs[?OutputKey==\'DistributionId\'].OutputValue" --output text) --paths "/*"', {
    stdio: 'inherit'
  });

  console.log('\n✅ Frontend deployment completed successfully!');

} catch (error) {
  console.error('\n❌ Frontend deployment failed:', error.message);
  process.exit(1);
}
