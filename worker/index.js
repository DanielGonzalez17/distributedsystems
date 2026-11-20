import amqp from "amqplib";
import { MongoClient } from "mongodb";

const required = (name) => {
  const value = process.env[name];
  if (!value) throw new Error(`Missing required environment variable: ${name}`);
  return value;
};

const QUEUE = "reviews.queue";
const DLQ = "reviews.dlq";

const start = async () => {
  const mongo = new MongoClient(
    `mongodb://${required("MONGO_HOST")}:${Number(process.env.MONGO_PORT || 27017)}/${encodeURIComponent(required("MONGO_DB"))}`,
    {
      auth: {
        username: required("MONGO_USER"),
        password: required("MONGO_PASSWORD"),
      },
      authSource: "admin",
    }
  );
  await mongo.connect();
  const reviews = mongo.db(required("MONGO_DB")).collection("product_reviews");

  const conn = await amqp.connect(required("RABBITMQ_URL"));
  const channel = await conn.createChannel();
  await channel.assertQueue(DLQ, { durable: true });
  await channel.assertQueue(QUEUE, {
    durable: true,
    deadLetterExchange: "",
    deadLetterRoutingKey: DLQ,
  });
  channel.prefetch(5);

  console.log("Review worker listening on", QUEUE);

  channel.consume(QUEUE, async (msg) => {
    if (!msg) return;
    try {
      const payload = JSON.parse(msg.content.toString("utf8"));
      await reviews.insertOne({
        sku: payload.sku,
        reviewer: payload.reviewer,
        rating: payload.rating,
        comment: payload.comment,
        createdAt: new Date(payload.createdAt || Date.now()),
      });
      channel.ack(msg);
      console.log(`Saved review for SKU ${payload.sku} by ${payload.reviewer}`);
    } catch (err) {
      console.error("Failed processing review message, routing to DLQ:", err);
      channel.nack(msg, false, false);
    }
  });

  const shutdown = async () => {
    await channel.close();
    await conn.close();
    await mongo.close();
    process.exit(0);
  };
  process.on("SIGINT", shutdown);
  process.on("SIGTERM", shutdown);
};

start().catch((err) => {
  console.error("Worker startup failed:", err);
  process.exit(1);
});
